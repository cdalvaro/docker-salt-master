gitfs-pillar-email-is-present-and-string:
  test.check_pillar:
    - present:
      - docker-salt-master-test:email
    - string:
      - docker-salt-master-test:email
    - verbose: True
