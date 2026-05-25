.PHONY: help install syntax apply

INVENTORY ?= inventory/devboxes.yml

help:
	@echo "Hetzner Proxy Devbox"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Export HETZNER_TOKEN or HCLOUD_TOKEN"
	@echo "  - Copy inventory/host_vars/example-devbox.yml.example to .yml and edit it"
	@echo "  - Run: make install"
	@echo ""
	@echo "Commands:"
	@echo "  make install              Install Ansible collections"
	@echo "  make syntax               Syntax check playbooks/site.yml"
	@echo "  make apply HOST=<host>    Create/configure one devbox"

install:
	ansible-galaxy collection install -r requirements.yml

syntax:
	ansible-playbook -i $(INVENTORY) playbooks/site.yml --syntax-check

apply:
ifndef HOST
	$(error HOST is required. Usage: make apply HOST=example-devbox)
endif
	ansible-playbook -i $(INVENTORY) playbooks/site.yml -l $(HOST)
