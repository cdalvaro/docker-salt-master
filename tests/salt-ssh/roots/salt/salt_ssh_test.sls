salt_ssh_test_file:
  file.managed:
    - name: /tmp/salt-ssh-test.txt
    - contents: {{ pillar['salt_ssh_test']['message'] | yaml_dquote }}
