# Running External Identity Providers with ipalab-config

## Preparing the environment

Create the configuration:

```
python3 -m venv /tmp/ipalab
. /tmp/ipalab/bin/activate
pip install -r requirements.txt
```

Build the containers:

```
ipalab-config -f containerfile-fedora -p playbooks ipalab-eidp.yaml
cd ipa-idp-keycloak
podman-compose up -d --build
ansible-galaxy collection install -r requirements.yml
```

Deploy the IPA cluster:

```
ansible-playbook -i inventory.yml ${HOME}/.ansible/collections/ansible_collections/freeipa/ansible_freeipa/playbooks/install-cluster.yml
```

Configure keycloak:

```
ansible-galaxy collection install ansible.posix
ansible-playbook -i inventory.yml playbooks/establish-trust.yaml
```
