"""hook_git.py — find the git invocations inside a Claude Code Bash command.

The Bash guard hooks (block-no-verify, detect-secrets, git-push-reminder) used
to substring-match the raw command. That missed every spelling git accepts
(`git commit -n`, `-anm x`, `git -C repo commit`, `git -c core.hooksPath=…`)
and blocked text that merely mentioned a flag (`-m "explain --no-verify"`).
This module parses each git invocation's global options and subcommand, so the
hooks decide on what git would actually run (#249).

A parser is only as safe as its agreement with bash. Two rules keep it from
opening holes the old substring match did not have:

- Comments and heredoc bodies are removed by a scanner that tracks quoting,
  `$( … )` and `( … )` the way bash does — never by a regex or by shlex, which
  disagree with bash on `foo#bar`, a quoted `"<<EOF"` and `<<<`.
- When the command holds constructs the parser cannot see through (command
  substitution, backticks, xargs, eval, a `$VAR` as the program, git aliases,
  GIT_CONFIG_* / --config-env), the old literal-text floor applies on top:
  `--no-verify`, `hooksPath` or `HUSKY=0` anywhere in it blocks.

Usage (the PreToolUse payload JSON on stdin):

    python3 hook_git.py no-verify     exit 2 + reason on stdout if a git
                                      invocation skips hooks, else exit 0
    python3 hook_git.py commit-dirs   one line per `git commit`: the directory
                                      it runs in (after cd / -C); "." when a
                                      commit may run but cannot be located
    python3 hook_git.py has push      exit 0 if any invocation is `git push`,
                                      else exit 1

Exit 3 means the payload could not be read: the hook warns and lets the
command through (blocking every Bash call would make the machine unusable).
"""

import io
import json
import os
import posixpath
import re
import shlex
import subprocess
import sys

SEPARATORS = {"&&", "||", ";", "|", "|&", "&", "(", ")", ";;"}
# Wrappers that run the rest of the line as a command.
WRAPPERS = {"command", "exec", "nohup", "time", "nice", "sudo", "builtin", "env"}
SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
# git global options that take a separate value.
GIT_GLOBAL_WITH_VALUE = {"-c", "-C", "--git-dir", "--work-tree", "--namespace",
                         "--exec-path", "--super-prefix", "--config-env"}
# `git commit` short options whose value follows (attached or as the next token).
COMMIT_SHORT_WITH_VALUE = set("mFCct")
# `git commit` short options whose value is optional and only ever attached.
COMMIT_SHORT_OPTIONAL = set("uS")
# `git commit` long options that take a value (as `--x=v` or `--x v`).
COMMIT_LONG_WITH_VALUE = {"--message", "--file", "--author", "--date",
                          "--template", "--reuse-message", "--reedit-message",
                          "--fixup", "--squash", "--cleanup", "--trailer",
                          "--pathspec-from-file"}
NO_VERIFY = "--no-verify"
# git accepts any unambiguous prefix of a long option. Where it is ambiguous
# (`--no-ve` on commit, which also has --no-verbose) git refuses to run, so
# blocking every prefix from `--no-v` (unambiguous on am) costs nothing.
NO_VERIFY_MIN_PREFIX = len("--no-v")
# Constructs whose effect the parser cannot see. Their presence turns the
# literal-text floor on.
# Interpreters run code the shell parser cannot read (python -c, a heredoc
# script, perl -e, node -e, env -S …).
INTERP = r"(^|[\s;&|(`]|\$\()(python\d*(\.\d+)?|perl|node|ruby|php|deno|bun|env\s+-S)(\s|$)"
OPAQUE = re.compile(r"\$'|\$\(|`|\bxargs\b|\beval\b|\bsource\b|alias\.|--config-env"
                    r"|GIT_CONFIG|(^|[;&|(\n]\s*)(\w+=\S*\s+)*\$|" + INTERP)
# Built-in subcommands never resolve through an alias, so they skip the
# `git config alias.<x>` lookup below (one subprocess per unknown subcommand).
BUILTINS = {"add", "am", "apply", "bisect", "blame", "branch", "checkout", "cherry-pick",
            "clean", "clone", "commit", "config", "describe", "diff", "fetch", "grep",
            "init", "log", "ls-files", "merge", "mv", "pull", "push", "rebase", "reflog",
            "remote", "reset", "restore", "rev-parse", "revert", "rm", "show", "stash",
            "status", "switch", "tag", "worktree"}
# A heredoc fed to one of these is code, not data: its body counts for the floor.
SHELL_HEREDOC = re.compile(r"\b(bash|sh|zsh|dash|ksh|eval|source|xargs)\b[^\n]*<<(?!<)")
SHELL_PROG = re.compile(r"(^|[\s;&|(`]|\$\()(bash|sh|zsh|dash|ksh)(\s|$)")
FLOOR = (("--no-veri", "--no-verify"), ("hookspath", "core.hooksPath"), ("husky=0", "HUSKY=0"),
         ("skip=", "SKIP="), ("git_config", "GIT_CONFIG*"), ("include.path", "include.path"),
         ("includeif.", "includeIf.*"), ("--git-dir", "--git-dir"), ("--work-tree", "--work-tree"))


class ParseError(Exception):
    pass


def _scan(command, bodies=None):
    """Return the command with comments and heredoc bodies removed and
    unquoted newlines turned into `;`, deciding
    both by bash's own rules: `#` starts a comment only at the start of an
    unquoted word, and `<<` (not `<<<`) starts a heredoc only unquoted. Inside
    `$( … )` quoting starts afresh, as in bash. When `bodies` is a list, each
    removed heredoc is appended to it as (the line that opened it, body)."""
    out, stack, pending = [], ["top"], []   # pending: [(delimiter, strip_tabs)]
    line_start = 0                       # where the current RAW line began
    i, n = 0, len(command)
    while i < n:
        c, ctx = command[i], stack[-1]
        if ctx == "sq":
            out.append(c)
            if c == "'":
                stack.pop()
            i += 1
            continue
        if ctx == "ansi":                    # $'…': a backslash escapes even '
            if c == "\\" and i + 1 < n:
                out.append(command[i:i + 2])
                i += 2
                continue
            out.append(c)
            if c == "'":
                stack.pop()
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            if command[i + 1] != "\n":       # backslash-newline: a continuation
                out.append(command[i:i + 2])
            i += 2
            continue
        if ctx == "dq":
            if c == '"':
                stack.pop()
            elif command.startswith("$(", i):
                stack.append("sub")
                out.append("$(")
                i += 2
                continue
            elif c == "`":
                stack.append("bq")
            out.append(c)
            i += 1
            continue
        if ctx == "bq" and c == "`":
            stack.pop()
            out.append(c)
            i += 1
            continue
        # Unquoted: top level, ( … ), $( … ) or ` … `.
        if c == "\n":
            # The heredocs opened on this line are fed by the WHOLE line
            # (`cat <<EOF | sh` pipes the body into a shell after the `<<`).
            # Raw text: redirections (`> x.sh`) are already gone from `out`.
            line_text = command[line_start:i]
            pending = [(d, t, line_text) for d, t, _ in pending]
            out.append(" ; ")                 # shlex would glue it to a word
            i += 1
            body = []
            while pending and i < n:
                j = command.find("\n", i)
                line = command[i:] if j < 0 else command[i:j]
                delim, tabs, prefix = pending[0]
                i = n if j < 0 else j + 1
                if (line.lstrip("\t") if tabs else line) == delim:
                    pending.pop(0)
                    if bodies is not None:
                        bodies.append((prefix, "\n".join(body)))
                    body = []
                else:
                    body.append(line)
            line_start = i
            continue
        if c == "#" and (not out or out[-1][-1:] in " \t\n;&|()"):
            j = command.find("\n", i)
            i = n if j < 0 else j            # drop the comment, keep the newline
            continue
        if command.startswith("$((", i) or (command.startswith("((", i) and ctx != "arith"):
            # Arithmetic: `<<` there is a shift, never a heredoc.
            j = command.find("))", i)
            if j < 0:
                raise ParseError("unterminated arithmetic")
            out.append(command[i:j + 2])
            i = j + 2
            continue
        if command.startswith("$'", i):
            stack.append("ansi")
            out.append("$'")
            i += 2
            continue
        if c == "'":
            stack.append("sq")
        elif c == '"':
            stack.append("dq")
        elif c == "`":
            stack.append("bq")
        elif command.startswith("$(", i):
            stack.append("sub")
            out.append("$(")
            i += 2
            continue
        elif c == "(":
            stack.append("par")
        elif c == ")" and ctx in ("sub", "par"):
            stack.pop()
        elif command.startswith("<<<", i):
            i = _skip_redirect_target(command, i + 3)   # a here-string is data
            out.append(" ")
            continue
        elif (c in "<>" or (c == "&" and command.startswith("&>", i))) \
                and not command.startswith("<<", i) and not command.startswith(("<(", ">("), i):
            # A redirection (N>file, >>, <, &>, N>&M, >|): drop it and its
            # target. shlex would split `2>&1` at the `&` — read as a command
            # separator — and lose the words after it.
            while out and out[-1].isdigit() and len(out) > 1 and out[-2][-1:] in " \t":
                out.pop()                    # the fd number before it (2>…)
            j = i + 1
            while j < n and command[j] in "<>&|":
                j += 1
            if command[i:j].endswith("&") and j < n and (command[j].isdigit() or command[j] == "-"):
                j += 1                       # N>&M / >&-
                while j < n and command[j].isdigit():
                    j += 1
                i = j
            else:
                i = _skip_redirect_target(command, j)
            out.append(" ")
            continue
        elif command.startswith("<<", i):
            # The delimiter is one shell word; bash removes every quote and
            # backslash in it ('E'OF, E\OF and "EOF" all mean EOF).
            m = re.match(r"<<(-?)[ \t]*((?:'[^']*'|\"[^\"]*\"|\\.|[^\s;&|()<>'\"\\])+)",
                         command[i:])
            if m:
                delim = re.sub(r"\\(.)", r"\1", re.sub(r"'([^']*)'|\"([^\"]*)\"",
                               lambda q: q.group(1) if q.group(1) is not None else q.group(2),
                               m.group(2)))
                pending.append((delim, bool(m.group(1)), ""))
                out.append(m.group(0))
                i += m.end()
                continue
        out.append(c)
        i += 1
    if pending:
        # A heredoc that never closes (or a `<<` that was arithmetic, as in
        # $((1<<2))): the scanner's view may not match bash's. Treat the
        # command as opaque, so the literal floor reads the RAW text.
        raise ParseError("unterminated heredoc")
    return "".join(out)


def _skip_redirect_target(command, i):
    """Index just past the word a redirection points at (quotes included)."""
    n = len(command)
    while i < n and command[i] in " \t":
        i += 1
    quote = None
    while i < n:
        c = command[i]
        if quote:
            if c == "\\" and quote == '"' and i + 1 < n:
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "'\"":
            quote = c
        elif c == "\\" and i + 1 < n:
            i += 2
            continue
        elif c in " \t\n;&|()<>":
            break
        i += 1
    return i


def _tokens(command):
    lex = shlex.shlex(command, posix=True, punctuation_chars=";&|()")
    lex.whitespace = " \t\r"          # keep newlines: they separate commands
    lex.whitespace_split = True
    lex.commenters = ""               # comments were removed by _scan
    try:
        return list(lex)
    except ValueError as exc:          # unbalanced quotes
        raise ParseError(str(exc))


def _segments(tokens):
    """Yield (words, their indices in `tokens`) per simple command."""
    seg, idx = [], []
    for n, tok in enumerate(tokens):
        if tok in SEPARATORS or set(tok) <= set(";&|()\n") or ("\n" in tok and not tok.strip("\n")):
            if seg:
                yield seg, idx
            seg, idx = [], []
        else:
            seg.append(tok)
            idx.append(n)
    if seg:
        yield seg, idx


def _is_assignment(tok):
    name, eq, _ = tok.partition("=")
    return bool(eq) and bool(name) and name.replace("_", "a").isalnum() and not name[0].isdigit()


GIT_DASH = re.compile(r"git-([a-z][a-z0-9-]*?)(\.exe)?")


def _is_git(tok):
    """`git`, or a direct `git-<sub>` entry point (…/git-core/git-commit)."""
    base = posixpath.basename(tok.replace("\\", "/")).lower()
    return base in ("git", "git.exe") or bool(GIT_DASH.fullmatch(base))


def _join(cwd, target):
    """The directory `cd target` / `git -C target` lands in; None when it
    cannot be known statically (an unknown base, or a $VAR / backtick)."""
    if cwd is None or "$" in target or "`" in target:
        return None
    return posixpath.normpath(posixpath.join(cwd, posixpath.expanduser(target)))


def invocations(command, cwd=".", env=None, depth=0):
    """Yield one dict per git invocation: env, config, cwd, sub, args.
    Paths are POSIX on every platform: the command is bash (Git Bash on
    Windows), and a `\\`-separated path would mean nothing to it."""
    if depth > 3:
        raise ParseError("nested too deeply")
    env = dict(env or {})                 # exported / assigned so far
    bodies = []
    segments = list(_segments(_tokens(_scan(command, bodies))))
    # A heredoc fed to a shell (`bash <<'EOF'`) is a script: parse its body.
    for line, body in bodies:
        if SHELL_PROG.search(line):
            yield from invocations(body, cwd, env, depth + 1)
    for seg, idxs in segments:
        local, i = dict(env), 0
        while i < len(seg):
            tok = seg[i]
            if _is_assignment(tok):
                k, _, v = tok.partition("=")
                local[k] = v
            elif tok in WRAPPERS:
                pass
            elif tok.startswith("-") and i > 0 and seg[i - 1] in WRAPPERS:
                pass                   # an option of the wrapper itself
            else:
                break
            i += 1
        rest, ridx = seg[i:], idxs[i:]
        if not rest:
            env.update(local)          # a bare `VAR=x` stays for later segments
            continue
        prog = posixpath.basename(rest[0].replace("\\", "/")).lower()
        if prog == "export":
            for tok in rest[1:]:
                if _is_assignment(tok):
                    k, _, v = tok.partition("=")
                    env[k] = v
            continue
        if prog == "cd":
            target = rest[1] if len(rest) > 1 else "~"
            cwd = None if target == "-" else _join(cwd, target)
            continue
        if prog in ("pushd", "popd"):
            cwd = None                  # a directory stack: not modelled
            continue
        if prog in SHELLS:
            # `-c`, alone or in a cluster (`-ec`, `-xc`): the next word is a script.
            j = next((k for k, t in enumerate(rest[1:], 1)
                      if re.fullmatch(r"-[a-zA-Z]*c[a-zA-Z]*", t)), None)
            if j is not None and j + 1 < len(rest):
                yield from invocations(rest[j + 1], cwd, local, depth + 1)
                continue
        if not _is_git(rest[0]):
            # A wrapper or keyword the parser does not model (`timeout 5 git`,
            # `nice -n 5 git`, `{ git`, `! git`, `if git`, `find -exec git`,
            # `xargs git`): parse from the first `git` word, keeping any
            # assignments in between (`timeout 5 env HUSKY=0 git …`).
            k = next((k for k, t in enumerate(rest[1:], 1) if _is_git(t)), None)
            if k is None:
                continue
            for tok in rest[1:k]:
                if _is_assignment(tok):
                    key, _, val = tok.partition("=")
                    local[key] = val
            rest, ridx = rest[k:], [None] * len(ridx[k:])   # no message exemption
        dash = GIT_DASH.fullmatch(posixpath.basename(rest[0].replace("\\", "/")).lower())
        if dash:                         # git-commit … == git commit …
            rest, ridx = ["git", dash.group(1)] + rest[1:], [ridx[0]] + ridx
        config, gcwd, j = [], cwd, 1
        while j < len(rest) and rest[j].startswith("-"):
            opt = rest[j]
            name, eq, val = opt.partition("=")
            if name in GIT_GLOBAL_WITH_VALUE and not eq and j + 1 < len(rest):
                val, j = rest[j + 1], j + 2
            else:
                j += 1
                if not eq and opt.startswith("-c") and len(opt) > 2:
                    name, val = "-c", opt[2:]
            if name == "-c":
                config.append(val)
            elif name == "--config-env":
                config.append(val.split("=", 1)[0] + "=$env")
            elif name == "-C":
                gcwd = _join(gcwd, val)
            elif name in ("--git-dir", "--work-tree"):
                config.append(f"{name}={val}")
        if j >= len(rest):
            continue
        # arg_idx: positions of the args in the outer token stream, so the
        # literal floor can exempt exactly those tokens; None when nested
        # (bash -c, a heredoc script), whose words are not in that stream.
        yield {"env": local, "config": config, "cwd": gcwd,
               "sub": rest[j], "args": rest[j + 1:], "depth": depth,
               "arg_idx": ridx[j + 1:] if depth == 0 and None not in ridx else None}


EXPANDS = re.compile(r"\$|\{[^}]*,[^}]*\}")   # $VAR, $(…), $'…', {a,b}
GLOB = set("*?[")


def _may_glob_to_flag(arg):
    """An unquoted glob the shell may expand to a file named like a flag
    (`-[n]`, `?n`, `*`). A path glob such as `src/*.js` cannot start with -."""
    return bool(GLOB & set(arg)) and (arg[0] == "-" or arg[0] in GLOB)


def _commit_scan(args):
    """Return (flag that skips hooks or None, positions in `args` of the
    tokens that hold option values such as the -m message). An argument the shell will still expand ($VAR, {a,b}) cannot be
    checked, so it counts as skipping hooks — except as an option's value."""
    values, i = [], 0
    while i < len(args):
        a = args[i]
        if a == "--":
            break
        if a.startswith("--"):
            name, eq, val = a.partition("=")
            if len(name) >= NO_VERIFY_MIN_PREFIX and NO_VERIFY.startswith(name):
                return a, values
            if name in COMMIT_LONG_WITH_VALUE:
                if eq:
                    values.append(i)
                elif i + 1 < len(args):
                    i += 1
                    values.append(i)
            elif EXPANDS.search(a) or _may_glob_to_flag(a):
                return a, values
        elif a.startswith("-") and len(a) > 1 and _may_glob_to_flag(a):
            return a, values
        elif a.startswith("-") and len(a) > 1:
            for k, ch in enumerate(a[1:], 1):
                if ch == "n":
                    return a, values
                if ch in COMMIT_SHORT_WITH_VALUE:
                    if k < len(a) - 1:
                        values.append(i)
                    elif i + 1 < len(args):
                        i += 1
                        values.append(i)
                    break          # the rest of the cluster is the value
                if ch in COMMIT_SHORT_OPTIONAL:
                    break
                if ch in "${":
                    return a, values
        elif EXPANDS.search(a) or _may_glob_to_flag(a):
            return a, values       # could expand to a flag
        i += 1
    return None, values


def _commit_skips_hooks(args):
    return _commit_scan(args)[0]


def _redirects_hooks(key):
    """core.hooksPath itself, or an include that can bring one in."""
    key = key.lower()
    return key == "core.hookspath" or key == "include.path" or (
        key.startswith("includeif.") and key.endswith(".path"))


def _config_skips_hooks(config, env):
    for kv in config:
        if _redirects_hooks(kv.split("=", 1)[0]):
            return f"git -c {kv} (points hooks away)"
    for k, v in env.items():
        if k.startswith("GIT_CONFIG") and "hookspath" in v.lower():
            return f"{k}={v} (points hooks away)"
    return None


# Assignments that swap the config git reads (and so core.hooksPath) for one
# the guard cannot see. Blocked on the subcommands that run hooks.
CONFIG_ENV = re.compile(r"GIT_CONFIG\w*|HOME|XDG_CONFIG_HOME|GIT_DIR|GIT_COMMON_DIR")
# An alias value that runs a shell or passes a hook-skipping short flag.
ALIAS_RISK = re.compile(r"^\s*!|--no-veri|hookspath", re.I)
# Subcommands (other than commit) whose short flag means --no-verify.
NO_VERIFY_SHORT = {"am": "n"}
CONFIG_READ_OPTS = {"--get", "--get-all", "--get-regexp", "--list", "-l", "--unset", "--unset-all"}
CONFIG_VALUE_OPTS = {"-f", "--file", "--blob", "--type", "--default", "--comment", "--value",
                     "--url"}
HOOK_SUBS = {"commit", "push", "merge", "am", "rebase", "cherry-pick", "revert", "pull"}


UNKNOWN_ALIAS = "!unknown"


def _lookup_alias(sub, cwd):
    try:
        # The directory may be an untrusted clone: no code from its config.
        out = subprocess.run(["git", "-c", "core.fsmonitor=false", "-C", cwd or ".",
                              "config", "--get", f"alias.{sub}"],
                             capture_output=True, text=True, timeout=5,
                             env=dict(os.environ, GIT_CONFIG_NOSYSTEM="1"))
    except Exception:                    # no git, timeout: cannot tell
        return UNKNOWN_ALIAS
    if out.returncode == 0:
        return out.stdout.strip()
    return None if out.returncode == 1 else UNKNOWN_ALIAS   # 1 = not set


def _configured_alias(sub, cwd):
    """The alias body from git config, None when there is none, or
    UNKNOWN_ALIAS when the lookup itself failed (a directory that does not
    exist yet, no git). A `cd` the parser followed may not be where the
    command really runs (a subshell, `cd x;` that failed), so the starting
    directory is consulted too."""
    for where in dict.fromkeys([cwd or ".", "."]):
        body = _lookup_alias(sub, where)
        if body:
            return body
    return None


def no_verify_reason(inv, depth=0):
    reason = _config_skips_hooks(inv["config"], inv["env"])
    if reason:
        return reason
    # A git alias runs another subcommand (or, with `!`, a shell command).
    aliases = {kv.split("=", 1)[0][len("alias."):].lower(): kv.split("=", 1)[1]
               for kv in inv["config"] if kv.lower().startswith("alias.") and "=" in kv}
    if inv["sub"].lower() not in aliases and inv["sub"] not in BUILTINS:
        if inv["cwd"] is None:
            # Could be an alias of a repository we cannot resolve: fail closed.
            return f"git {inv['sub']} in a directory the guard cannot resolve (possible alias)"
        body = _configured_alias(inv["sub"], inv["cwd"])   # ~/.gitconfig, .git/config
        if body == UNKNOWN_ALIAS:
            return f"git {inv['sub']}: could not check whether it is an alias"
        if body:
            aliases[inv["sub"].lower()] = body
    if inv["sub"].lower() in aliases and depth >= 3:
        return f"alias {inv['sub']}: a chain of aliases too deep to check"
    if inv["sub"].lower() in aliases and depth < 3:
        body = aliases[inv["sub"].lower()]
        if body.startswith("!"):
            reason = _floor(body[1:])
            if reason:
                return f"alias {inv['sub']}: {reason}"
            try:
                for sub in invocations(body[1:], inv["cwd"], inv["env"], depth + 1):
                    reason = no_verify_reason(sub, depth + 1)
                    if reason:
                        return f"alias {inv['sub']}: {reason}"
            except ParseError:
                return f"alias {inv['sub']} could not be read"
            return None
        try:
            words = shlex.split(body)
        except ValueError:
            return f"alias {inv['sub']} could not be read"
        if words:
            expanded = dict(inv, sub=words[0], args=words[1:] + inv["args"])
            reason = no_verify_reason(expanded, depth + 1)
            return f"alias {inv['sub']}: {reason}" if reason else None
    if inv["sub"] in HOOK_SUBS:
        for kv in inv["config"]:
            if kv.startswith(("--git-dir=", "--work-tree=")):
                return f"git {kv.split('=', 1)[0]} … {inv['sub']} (a repository the guard cannot verify)"
        for k in inv["env"]:
            if CONFIG_ENV.fullmatch(k) and inv["env"].get(k) != os.environ.get(k):
                return f"{k}=… before git {inv['sub']} (config the guard cannot verify)"
    if EXPANDS.search(inv["sub"]):
        return f"git {inv['sub']} (a subcommand the guard cannot resolve)"
    if inv["sub"] == "config":
        # Read or write is decided only by what comes BEFORE the key: an
        # option (--get…, --unset…, --list) or a subcommand (get, unset, list).
        reading, seen_word, skip = False, False, False
        for k, a in enumerate(inv["args"]):
            low = a.lower()
            if skip:                     # the value of an option such as --file
                skip = False
                continue
            if low in CONFIG_READ_OPTS:
                reading = True
                continue
            if low in CONFIG_VALUE_OPTS:
                skip = True
                continue
            if low.startswith("-"):
                continue
            if not seen_word:
                seen_word = True
                if low in ("get", "list", "unset"):   # subcommand: first word only
                    reading = True
                    continue
            key, eq, val = a.partition("=")
            key = key.lower()
            if key.startswith("alias.") and not reading:
                value = val if eq else " ".join(inv["args"][k + 1:])
                words = value.split()
                commit_n = bool(words) and words[0] == "commit" and _commit_skips_hooks(words[1:])
                if commit_n or ALIAS_RISK.search(value) or OPAQUE.search(value) or _floor(value):
                    return f"git config {a.split('=', 1)[0]} (an alias that may skip hooks)"
                break
            if _redirects_hooks(key):
                if not reading and (eq or k + 1 < len(inv["args"])):
                    return f"git config {a} (points hooks away, persistently)"
                break
    if inv["sub"] == "commit":
        flag = _commit_skips_hooks(inv["args"])
        if flag:
            return f"git commit {flag} (skips pre-commit hooks)"
        husky = inv["env"].get("HUSKY")
        # Only a literal that is not an "off" value is provably safe.
        if husky is not None and (husky.lower() in ("0", "false", "") or re.search(r"[$`'\"]", husky)):
            return f"HUSKY={husky} (may disable husky hooks)"
        if inv["env"].get("SKIP"):
            return "SKIP=… (skips pre-commit framework hooks)"
    else:
        short = NO_VERIFY_SHORT.get(inv["sub"])
        for a in inv["args"]:
            if a == "--":
                break
            name = a.split("=", 1)[0]
            if len(name) >= NO_VERIFY_MIN_PREFIX and NO_VERIFY.startswith(name):
                return f"git {inv['sub']} {a} (skips hooks)"
            if short and re.fullmatch(r"-[a-zA-Z0-9]+", a) and short in a:
                return f"git {inv['sub']} {a} (skips hooks)"
    return None


# `commit … -n` (alone or in a cluster) as text, for opaque commands only.
# Also in list form (subprocess.run(['git', 'commit', '-n'])).
COMMIT_N = re.compile(r"\bcommit\b[^;&|\n]*[\s'\",\[(]-[a-zA-Z]*n[a-zA-Z]*\b")
DATA_SINK = re.compile(r"(^|[\s;&|(`]|\$\()cat(\s|$)")


def _code_bodies(command):
    """Heredoc bodies that are NOT plain data. Only a body read by `cat` (how
    commit messages are written: -m "$(cat <<'EOF' … EOF)") is data; a body
    fed to anything else — python3 <<EOF, a shell, a pipe into one — may run."""
    bodies = []
    try:
        _scan(command, bodies)
    except ParseError:
        return [command]
    # `cat <<EOF > x.sh` writes a file that may run next: not data either.
    return [body for line, body in bodies
            if not DATA_SINK.search(line) or SHELL_PROG.search(line) or re.search(INTERP, line)
            or re.search(r"(^|[^<>&0-9])>{1,2}\s*[^&\s]", line.replace("<<", ""))]
ALWAYS_FLOOR = (("--no-veri", "--no-verify"), ("husky=0", "HUSKY=0"))


def _token_floor(command, invs):
    """The old literal rule, kept as a floor under the parser on every
    command: an unmodelled program (`python -c`, an alias, a function) may
    still pass the flag to git. Only what is provably data is exempt: commit
    message values (-m/--message/-F…) and heredoc bodies read by cat."""
    try:
        tokens = _tokens(_scan(command))
    except ParseError:
        return None                      # the opaque floor covers this case
    exempt = set()
    for inv in invs:
        if inv["sub"] == "commit" and inv["arg_idx"] is not None:
            exempt.update(inv["arg_idx"][r] for r in _commit_scan(inv["args"])[1])
    for n, tok in enumerate(tokens):
        if n in exempt:
            continue
        low = tok.lower()
        for needle, label in ALWAYS_FLOOR:
            if needle in low:
                return f"{label} in the command"
        # A word that is itself a command line (ssh host "…", su -c "…",
        # script -c "…"): an unmodelled runner may execute it.
        if " " in tok and re.search(r"\bgit\b", low):
            if COMMIT_N.search(tok):
                return "commit -n in a command string"
            if "hookspath" in low:
                return "core.hooksPath in a command string"
    for body in _code_bodies(command):
        low = body.lower()
        for needle, label in ALWAYS_FLOOR:
            if needle in low:
                return f"{label} in a heredoc script"
    return None


def _floor(command):
    """The old literal-text rule, for commands the parser cannot see through.
    Heredoc bodies read by `cat` are skipped — `$(cat <<'EOF' … EOF)` is how
    commit messages are written, and a message may mention --no-verify — but
    a body fed to anything else may run, so it is read."""
    try:
        text = command if SHELL_HEREDOC.search(command) else _scan(command)
    except ParseError:
        text = command
    text = "\n".join([text] + _code_bodies(command))
    low = text.lower()
    for needle, label in FLOOR:
        if needle in low:
            return f"{label} in a command the guard cannot fully parse"
    if COMMIT_N.search(text):
        return "commit -n in a command the guard cannot fully parse"
    return None


def _with_session_aliases(invs):
    """`git config alias.x …; git x`: an alias written earlier in the same
    command is not in any config file yet — carry it to the later calls."""
    written = []
    for inv in invs:
        inv["config"] = inv["config"] + written
        if inv["sub"] == "config":
            args = inv["args"]
            for k, a in enumerate(args):
                key, eq, val = a.partition("=")
                if key.lower().startswith("alias."):
                    value = val if eq else " ".join(args[k + 1:])
                    written.append(f"{key}={value}")
                    break
    return invs


CONFIG_FILE = r"(\.git/config|\.gitconfig|git/config|\.git/hooks)"
WRITES = re.compile(r"(>>?|\btee\b|\bcp\b|\bmv\b|\brm\b|\bln\b|\bchmod\b|\bsed\s+-i|\bdd\b|\binstall\b)"
                    r"[^;&|\n]*" + CONFIG_FILE)
HOOKS_WRITE = re.compile(WRITES.pattern.replace(CONFIG_FILE, r"\.git/hooks"))


def _unresolved_program(command):
    """A command word the shell will still expand (`gi?`, `$G`, `/usr/bin/g*`):
    the parser cannot know what runs, so the command is opaque."""
    try:
        return any(seg and (GLOB | {"$"}) & set(seg[0])
                   for seg, _ in _segments(_tokens(_scan(command))))
    except ParseError:
        return True


def _commit_sub(inv):
    """True when the invocation is a commit, directly or through an alias."""
    if inv["sub"] == "commit":
        return True
    if inv["sub"] in BUILTINS:
        return False
    aliases = {kv.split("=", 1)[0][len("alias."):].lower(): kv.split("=", 1)[1]
               for kv in inv["config"] if kv.lower().startswith("alias.") and "=" in kv}
    body = aliases.get(inv["sub"].lower())
    if body is None:
        if inv["cwd"] is None:
            return True                  # unresolvable: assume it may commit
        body = _configured_alias(inv["sub"], inv["cwd"]) or ""
        if body == UNKNOWN_ALIAS:
            return True
    return body.lstrip("!").split()[:1] == ["commit"] or "commit" in body


def main(argv):
    try:
        payload = json.load(sys.stdin)
    except ValueError as exc:
        print(f"cannot parse the payload: {exc}")
        return 3
    tool_input = payload.get("tool_input") if isinstance(payload, dict) else None
    command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    if not isinstance(command, str):
        print("cannot parse the payload: tool_input.command is not a string")
        return 3

    mode = argv[1] if len(argv) > 1 else ""
    try:
        invs = _with_session_aliases(list(invocations(command)) if command else [])
        # Writing git's config in the same command changes what the parser
        # assumed about it: opaque, so the floor (hooksPath included) applies.
        opaque = bool(OPAQUE.search(command)) or _unresolved_program(command) \
            or bool(WRITES.search(command))
    except ParseError as exc:
        invs, opaque = None, True        # not plain shell: trust nothing parsed


    if mode == "no-verify":
        if HOOKS_WRITE.search(command):
            print("changes .git/hooks (replacing or removing a hook disables it)")
            return 2
        for inv in invs or []:
            reason = no_verify_reason(inv)
            if reason:
                print(reason)
                return 2
        reason = (_floor(command) if opaque else None) or _token_floor(command, invs or [])
        if reason:
            print(reason)
            return 2
        return 0
    if mode == "commit-dirs":
        # A commit the parser cannot locate — no invocation found although the
        # text says commit, or a $VAR directory — is checked where the command
        # runs, instead of going unscanned.
        dirs = [inv["cwd"] or "." for inv in invs or [] if _commit_sub(inv)]
        # A subshell `( cd x … )` restores the directory when it closes, which
        # the parser does not model: whenever a commit is placed anywhere but
        # here, scan here too.
        if (dirs and any(d != "." for d in dirs)) or (not dirs and "commit" in command):
            dirs.append(".")
        for d in dirs:
            print(d)
        return 0
    if mode == "has" and len(argv) > 2:
        if invs is None:
            return 0 if f"git {argv[2]}" in command else 1
        return 0 if any(inv["sub"] == argv[2] for inv in invs) else 1
    print(f"usage: {argv[0]} no-verify | commit-dirs | has <subcommand>")
    return 64


def _guarded_main(argv):
    """A bug in the parser must not turn into "allow": on any unexpected
    error the literal floor decides, and only a clean floor lets it through."""
    # The hooks read this output in bash: on Windows, Python would end each
    # line with \r\n and every path would carry a stray \r (git -C fails).
    sys.stdout.reconfigure(newline="\n", errors="backslashreplace")
    raw = sys.stdin.read()
    sys.stdin = io.StringIO(raw)
    try:
        return main(argv)
    except Exception as exc:             # noqa: BLE001 — fail closed on the floor
        try:
            command = json.loads(raw)["tool_input"]["command"]
        except Exception:
            command = raw
        mode = argv[1] if len(argv) > 1 else ""
        if mode == "no-verify":
            reason = _floor(str(command))
            if reason:
                print(reason)
                return 2
        if mode == "commit-dirs" and "commit" in str(command):
            print(".")
            return 0
        if mode == "no-verify" and re.search(r"\bgit", str(command)):
            # A command that runs git and that the guard failed to read: block.
            print(f"the guard could not check this git command ({exc.__class__.__name__})")
            return 2
        print(f"internal error: {exc.__class__.__name__}: {exc}")
        return 3


if __name__ == "__main__":
    sys.exit(_guarded_main(sys.argv))
