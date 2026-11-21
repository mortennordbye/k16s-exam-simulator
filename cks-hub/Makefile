# CKS hub. Run "make" to see the commands.
SHELL := /bin/bash
K16S_DIR := repos/k16s-exam-simulator
K16S := $(K16S_DIR)/local/k16s-local
# Exam-like lab: CKS mocks, Kubernetes v1.37 (exam version), 2 workers, remote desktop.
K16S_FLAGS := --profile cks --k8s 1.37 --workers 2 --desktop --cpus 4 --memory 8 --disk 40
UI := http://localhost:8080/
DESKTOP := 'http://localhost:8080/desktop/vnc.html?autoconnect=true&resize=remote&reconnect=true&path=desktop/websockify'
TERMINAL := http://localhost:8080/terminal/

.DEFAULT_GOAL := help
.PHONY: help today up stop status exam desktop terminal ssh password rebuild destroy guide ui patch clean plan scaffolds drills facts docs killercoda

help: ## Show the commands
	@echo "CKS hub. Exam target 2026-12-17."
	@echo
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-11s %s\n", $$1, $$2}'

today: ## Show the plan row for today
	@d=$$(date +%m-%d); grep -E "\| [A-Z][a-z]{2} $$d \||\| $$d" 04-study-plan.md || echo "No row for $$d. Open 04-study-plan.md (make plan)."

up: ## Start the lab (creates it on the first run, about 10 min)
	@$(K16S) up $(K16S_FLAGS)
	@$(MAKE) --no-print-directory clean

stop: ## Stop the lab and free 8 GB RAM (state is kept)
	@$(K16S) stop

status: ## Show the lab state, URLs and candidate password
	@$(K16S) status

exam: ## THE practice place: questions left, remote desktop right (like the real exam)
	@open -a Firefox $(UI)

desktop: ## Remote desktop alone, full screen (no questions)
	@open -a Firefox $(DESKTOP)

terminal: ## Open the browser terminal in Firefox
	@open -a Firefox $(TERMINAL)

ssh: ## Root shell on the control plane (then: ssh node01 / ssh node02)
	@$(K16S) ssh --root

password: ## Show the candidate password
	@limactl shell k16s -- sudo cat /etc/k16s/candidate-password

rebuild: ## Delete the lab and build it again from zero (about 10 min)
	@$(K16S) destroy --yes
	@$(MAKE) --no-print-directory up

destroy: ## Delete the lab VM
	@$(K16S) destroy --yes

guide: ## Copy 07-scaffolds.md into the exam UI guide and rebuild the UI
	@cp 07-scaffolds.md $(K16S_DIR)/server/frontend/src/lib/guide.md
	@$(MAKE) --no-print-directory ui

ui: ## Rebuild the exam UI after a change (about 30 s)
	@limactl shell k16s -- bash -lc 'sudo rm -f /usr/local/bin/k16s-server && sudo bash $$HOME/k16s/provision/k16s-server.sh' > /dev/null
	@$(MAKE) --no-print-directory clean patch
	@echo "  UI rebuilt. Reload the exam page."

patch: ## Save the local K16S changes to patches/
	@git -C $(K16S_DIR) add -N server/frontend/src/lib/guide.js server/frontend/src/lib/guide.md
	@git -C $(K16S_DIR) diff -- local/lima.yaml provision server/frontend/src > patches/k16s-exam-simulator.patch
	@echo "  patches/k16s-exam-simulator.patch updated"

clean: ## Free disk in the lab VM (apt, Go and npm caches)
	@limactl shell k16s -- sudo bash -c 'apt-get clean; rm -rf /root/.cache/go-build /root/go/pkg/mod /root/.npm; journalctl --vacuum-size=100M -q' >/dev/null 2>&1 || true
	@limactl shell k16s -- df -h / | tail -1 | awk '{print "  VM disk: " $$4 " free of " $$2}'

plan: ## Open the study plan
	@open 04-study-plan.md

scaffolds: ## Open the scaffold map (where to copy each YAML from)
	@open 07-scaffolds.md

drills: ## Open the drills
	@open 05-drills.md

facts: ## Open the exam facts
	@open 02-exam-facts.md

docs: ## Open kubernetes.io docs in Firefox (the main allowed doc)
	@open -a Firefox https://kubernetes.io/docs/

killercoda: ## Open the free Killercoda CKS scenarios in Firefox
	@open -a Firefox https://killercoda.com/killer-shell-cks
