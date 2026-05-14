{% if salt['pillar.get']('foo:encrypted') == 'Hello, test.minion!' %}
gpg-encrypted-pillar-is-decrypted:
  test.succeed_without_changes:
    - name: foo:encrypted decrypted correctly
{% else %}
gpg-encrypted-pillar-is-decrypted:
  test.fail_without_changes:
    - name: foo:encrypted decrypted incorrectly
{% endif %}
