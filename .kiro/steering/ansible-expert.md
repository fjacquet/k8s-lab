---
inclusion: always
---

# Ansible Expert Guidance

## Core Concepts

### Inventory

- Defines hosts and groups
- Formats: INI, YAML
- Location: `inventory.yml`, `hosts`, or custom path
- Dynamic inventory: Pull from cloud providers, CMDB, etc.

### Playbooks

- YAML files defining automation tasks
- Composed of plays (host groups + tasks)
- Idempotent by design
- Run with: `ansible-playbook playbook.yml`

### Roles

- Reusable, modular automation units
- Standard directory structure: tasks, handlers, templates, files, vars, defaults, meta
- Shareable via Ansible Galaxy

## Project Structure Best Practices

### Standard Layout

```
project/
├── inventory.yml          # Inventory definition
├── ansible.cfg           # Ansible configuration
├── playbook.yml          # Main playbook
├── group_vars/           # Variables per group
│   └── all.yml
├── host_vars/            # Variables per host
│   └── hostname.yml
├── roles/                # Custom roles
│   ├── common/
│   ├── webserver/
│   └── database/
└── templates/            # Jinja2 templates
    └── config.j2
```

### Inventory Structure

```yaml
all:
  hosts:
    node-1:
      ansible_host: 192.168.1.101
    node-2:
      ansible_host: 192.168.1.102
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
  children:
    servers:
      hosts:
        node-1:
    agents:
      hosts:
        node-2:
```

## Role Development

### Role Directory Structure

```
roles/role_name/
├── tasks/
│   └── main.yml          # Main task list
├── handlers/
│   └── main.yml          # Handlers (triggered by notify)
├── templates/
│   └── config.j2         # Jinja2 templates
├── files/
│   └── script.sh         # Static files
├── vars/
│   └── main.yml          # Role variables (high priority)
├── defaults/
│   └── main.yml          # Default variables (low priority)
└── meta/
    └── main.yml          # Role dependencies and metadata
```

### Task Best Practices

- Use descriptive task names
- Add `become: yes` for privilege escalation
- Use `when:` for conditional execution
- Register task results for later use
- Use `changed_when:` to control change reporting
- Add `tags:` for selective execution

## Module Usage

### Common Modules

- **shell/command**: Execute commands (use sparingly, prefer specific modules)
- **copy**: Copy files to remote hosts
- **template**: Process Jinja2 templates and copy
- **file**: Manage files and directories
- **apt/yum/dnf**: Package management
- **service/systemd**: Service management
- **user/group**: User and group management
- **git**: Git repository operations
- **uri**: HTTP requests
- **wait_for**: Wait for conditions

### Kubernetes-Specific Modules

- **kubernetes.core.k8s**: Manage Kubernetes resources
- **kubernetes.core.helm**: Manage Helm charts
- **kubernetes.core.k8s_info**: Query Kubernetes resources

## Templating with Jinja2

### Variable Substitution

```jinja2
server: https://{{ hostvars['node-1'].ansible_host }}:9345
token: {{ rke2_token }}
```

### Conditionals

```jinja2
{% if enable_feature %}
feature: enabled
{% endif %}
```

### Loops

```jinja2
{% for item in items %}
- {{ item }}
{% endfor %}
```

## Variable Precedence (Low to High)

1. Role defaults
2. Inventory file/script group vars
3. Inventory group_vars/all
4. Playbook group_vars/all
5. Inventory group_vars/*
6. Playbook group_vars/*
7. Inventory file/script host vars
8. Inventory host_vars/*
9. Playbook host_vars/*
10. Host facts
11. Play vars
12. Play vars_prompt
13. Play vars_files
14. Role vars
15. Block vars
16. Task vars
17. Extra vars (command line `-e`)

## Handlers

### Definition

```yaml
# handlers/main.yml
- name: restart service
  systemd:
    name: myservice
    state: restarted
```

### Usage

```yaml
# tasks/main.yml
- name: Update config
  template:
    src: config.j2
    dest: /etc/myapp/config.yml
  notify: restart service
```

## Error Handling

### Ignore Errors

```yaml
- name: Task that might fail
  command: /bin/false
  ignore_errors: yes
```

### Failed When

```yaml
- name: Check status
  command: check_status.sh
  register: result
  failed_when: "'ERROR' in result.stdout"
```

### Rescue and Always

```yaml
- block:
    - name: Risky task
      command: risky_command
  rescue:
    - name: Handle failure
      debug:
        msg: "Task failed, handling..."
  always:
    - name: Cleanup
      file:
        path: /tmp/temp
        state: absent
```

## Ansible Configuration

### ansible.cfg

```ini
[defaults]
inventory = inventory.yml
remote_user = ubuntu
private_key_file = ~/.ssh/id_rsa
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

[privilege_escalation]
become = True
become_method = sudo
become_user = root
```

## Best Practices

### Idempotency

- Always write idempotent tasks
- Use modules instead of shell/command when possible
- Test playbooks multiple times

### Security

- Use Ansible Vault for sensitive data
- Encrypt with: `ansible-vault encrypt vars/secrets.yml`
- Decrypt with: `ansible-vault decrypt vars/secrets.yml`
- Run with: `ansible-playbook --ask-vault-pass playbook.yml`

### Performance

- Use `gather_facts: no` when facts not needed
- Enable fact caching
- Use `async` and `poll` for long-running tasks
- Limit parallelism with `serial` or `forks`

### Testing

- Use `--check` mode for dry runs
- Use `--diff` to see changes
- Test in isolated environments first
- Use `ansible-lint` for linting playbooks

### Documentation

- Document variables in defaults/main.yml
- Add comments for complex logic
- Create README.md for roles
- Use `meta/main.yml` for role metadata
