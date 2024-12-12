Output "000-deploy.webm"

Source inc/base.tape

Type "# Let's clone the automation project"
Sleep 500ms
Enter

Type "git clone https://github.com/f-trivino/freeipa-local-tests.git -b podman && cd freeipa-local-tests"
Sleep 500ms
Enter


Type "# Let's install ipalab-config and ansible-freeipa"
Sleep 500ms
Enter

Type "python3 -m venv ipalab && cd ipalab && source bin/activate"
Sleep 500ms
Enter

Type 'pip install "ansible-core<2.18" ipalab-config'
Sleep 500ms
Enter

Type "ansible-galaxy collection install freeipa.ansible_freeipa"
Sleep 500ms
Enter



Type "# Let's deploy the multihost clusters and deploy FreeIPA"
Sleep 500ms
Enter

Type "ipalab-config -f ../image/containerfile ../examples/multihost.clusters && cd multihost"
Sleep 500ms
Enter

Type "podman-compose up -d"
Sleep 500ms
Enter

Type "ansible-playbook -i inventory.yml playbooks/install-cluster.yml"
Sleep 500ms
Enter


Type "# Let's play with the development preview feature"
Sleep 500ms
Enter

Type "ansible-playbook -i inventory.yml ../data/establish-trust.yaml"
Sleep 500ms
Enter

