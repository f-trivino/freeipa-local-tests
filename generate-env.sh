dnf -y install libvirt-devel krb5-devel python3-devel

podman build -t fedora-freeipa:40 -f Containerfile.build.fedora

python3 -m venv ipa-local-test

cd ipa-local-test
source bin/activate
pip3 install git+https://github.com/abbra/mrack@podman-freeipa
git clone --depth 1 https://github.com/freeipa/ansible-freeipa.git af

cp -r ../data .

cd data

mrack up -m metadata.yaml

deactivate

cd ..

cp data/ansible.cfg .

exit 0

export ANSIBLE_CONFIG=$(pwd)/ansible.cfg

# Install Server
ansible-playbook -i data/mrack-inventory.yaml -i data/ipa1demo.hosts \
                 -c podman af/playbooks/install-cluster.yml

# Install Client
podman stop client1-ipa1demo-test-local-freeipa-test-test
podman run --dns 10.89.0.4 -d --privileged --hostname client1.ipa1demo.test --name=client1-ipa1demo-test-local-freeipa-test-test --replace fedora-freeipa:40
podman exec -it client1-ipa1demo-test-local-freeipa-test-test ipa-client-install --domain ipa1demo.test --realm IPA1DEMO.TEST -N --mkhomedir -p admin --password=Secret123 -U


# Install Server
ansible-playbook -i data/mrack-inventory.yaml -i data/ipa2demo.hosts \
                 -c podman af/playbooks/install-cluster.yml

# Install Client
podman stop client2-ipa2demo-test-local-freeipa-test-test
podman run --dns 10.89.0.5 -d --privileged --hostname client2.ipa2demo.test --name=client2-ipa2demo-test-local-freeipa-test-test --replace fedora-freeipa:40
podman exec -it client2-ipa2demo-test-local-freeipa-test-test ipa-client-install --domain ipa2demo.test --realm IPA2DEMO.TEST -N --mkhomedir -p admin --password=Secret123 -U

ansible-playbook -i data/mrack-inventory.yaml \
                 -c podman data/establish-trust.yaml


