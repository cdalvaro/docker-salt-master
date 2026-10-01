"""Backport modern OpenSSH host-key prompt recognition to Salt 3007.15 only."""

from pathlib import Path

OLD_DETECTOR = r'KEY_VALID_RE = re.compile(r".*\(yes\/no\).*")'
# Matches the upstream fix already present in Salt 3008.2:
# https://github.com/saltstack/salt/blob/v3008.2/salt/client/ssh/shell.py
NEW_DETECTOR = r'KEY_VALID_RE = re.compile(r".*\(yes\/no(/\[fingerprint\])?\).*")'


def patch_host_key_prompt(version, shell_path):
    if version != "3007.15":
        return False

    source = shell_path.read_text()
    if OLD_DETECTOR not in source and source.count(NEW_DETECTOR) == 1:
        return False
    if source.count(OLD_DETECTOR) != 1:
        raise RuntimeError("Unexpected Salt 3007.15 host-key prompt detector; refusing to patch")

    patched = source.replace(OLD_DETECTOR, NEW_DETECTOR, 1)
    compile(patched, str(shell_path), "exec")
    shell_path.write_text(patched)
    return True


if __name__ == "__main__":
    import salt
    import salt.version

    shell_path = Path(salt.__file__).parent / "client" / "ssh" / "shell.py"
    if patch_host_key_prompt(salt.version.__version__, shell_path):
        print("Backported modern OpenSSH host-key prompt recognition to Salt 3007.15")
    else:
        print("Salt SSH host-key prompt detector left unchanged")
