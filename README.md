# FreeIPA Cluster Testing with Podman Containers

This project provides a framework for testing FreeIPA development features using clusters of Podman containers as FreeIPA ephemeral deplotments. The container images are built with experimental Fedora COPRs, including features in **Development Preview**, to enable rapid testing of new capabilities and configurations.

## Features

- **Cluster-based Testing**: Easily deploy clusters of FreeIPA instances as ephemeral deployments for advanced feature testing.
- **Experimental Images**: Leverages Fedora COPRs to include the latest development preview features.
- **Automation**: Simplifies setup and management of Podman-based FreeIPA clusters.

## Requirements

- Podman (latest stable version recommended)
- Fedora system or compatible Linux distribution
- Access to Fedora COPRs repositories for experimental builds

## Installation

### Installing System Dependencies
```bash
sudo dnf install -y git-core ansible ansible-collection-containers-podman podman gcc libvirt-devel krb5-devel python3-devel podman-compose
```

## Usage

1. **Clone the Repository**

    ```bash
    git clone https://github.com/f-trivino/freeipa-local-tests.git -b podman && cd freeipa-local-tests
    ```

2. **Install ipalab-config and ansible-freeipa**

    Usage of Python's virtual environment is encouraged:
    ```bash
    python3 -m venv ipalab && cd ipalab && source bin/activate
    pip install "ansible-core<2.18"
    pip install ipalab-config
    ansible-galaxy collection install freeipa.ansible_freeipa
    ```

3. **Deploy the multihost clusters and deploy FreeIPA**

    The tool ipalab-config will generate all needed files.
    ```bash
    ipalab-config -f ../image/containerfile ../examples/multihost.clusters && cd multihost
    sudo podman-compose up -d
    ansible-playbook -i inventory.yml playbooks/install-cluster.yml
    ```

4. **Play with the development preview feature**

    In this example you can see how to establish trust between two different IPA deployments.
    ![Establish IPA Trust](./videos/establish-trust.webm)

## Ansible

You can also develop your own Ansible playbooks to automate more complex configurations. Use standard Ansible playbooks to interact with the IPA deployments. In this example, an IPA trust is established between the ipa1demo and ipa2demo clusters:
    ```bash
    ansible-playbook -i inventory.yml ../data/establish-trust.yaml
    ```

## Troubleshooting

Make modifications on the development preview image:
```bash
compose down
compose up -d --build
```

Disaster recovery:
```bash
podman stop --all
podman system prune --all --force && podman rmi --all
```

ansible-core issues:
```bash
pip install --force 'ansible-core < 2.18'
```

How to connect to the containers:
```bash
podman ps 
podman exec -it m1 /bin/bash
```
