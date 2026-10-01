"""Backport modern OpenSSH host-key prompt recognition to Salt versions before 3008.0."""

from pathlib import Path

OLD_DETECTOR = r'KEY_VALID_RE = re.compile(r".*\(yes\/no\).*")'
# Matches the upstream fix already present in Salt 3008.0:
# https://github.com/saltstack/salt/blob/v3008.0/salt/client/ssh/shell.py
NEW_DETECTOR = r'KEY_VALID_RE = re.compile(r".*\(yes\/no(/\[fingerprint\])?\).*")'

# Remove this backport, its build hook and dedicated tests when Salt 3007.x support is retired.

def patch_host_key_prompt(version_info, shell_path):
    # Salt provides numeric version components; every 3008.x release is outside the backport.
    if version_info[0] >= 3008:
        return False

    source = shell_path.read_text()
    if OLD_DETECTOR not in source and source.count(NEW_DETECTOR) == 1:
        return False
    if source.count(OLD_DETECTOR) != 1 or NEW_DETECTOR in source:
        raise RuntimeError("Unexpected Salt host-key prompt detector; refusing to patch")

    patched = source.replace(OLD_DETECTOR, NEW_DETECTOR, 1)
    compile(patched, str(shell_path), "exec")
    shell_path.write_text(patched)
    return True


if __name__ == "__main__":
    import salt
    import salt.version

    shell_path = Path(salt.__file__).parent / "client" / "ssh" / "shell.py"
    if patch_host_key_prompt(salt.version.__version_info__, shell_path):
        print(f"Backported modern OpenSSH host-key prompt recognition to Salt {salt.version.__version__}")
    else:
        print("Salt SSH host-key prompt detector left unchanged")
