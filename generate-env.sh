dnf -y install libvirt-devel krb5-devel python3-devel

podman build -t fedora-freeipa:40 -f Containerfile.freeipa

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

export ANSIBLE_CONFIG=$(pwd)/ansible.cfg

ansible-playbook -i data/mrack-inventory.yaml -i data/ipa1demo.hosts \
                 -c podman af/playbooks/install-cluster.yml

ansible-playbook -i data/mrack-inventory.yaml -i data/ipa2demo.hosts \
                 -c podman af/playbooks/install-cluster.yml

ansible-playbook -i data/mrack-inventory.yaml \
                 -c podman data/establish-trust.yaml


