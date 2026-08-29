SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

OUTDIR := output
CSS := styles.css
MD := $(shell find . -maxdepth 1 -name '*.md' ! -name 'README.md')
PDF := $(patsubst ./%.md,$(OUTDIR)/%.pdf,$(MD))

# Non-interactive apt for CI/CD
APTENV := DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a

# Guide paths and output names (matching GitLab CI)
GUIDE_CLI_PATH := ../resources/documentation/cli-guide
GUIDE_CLI_PDF := $(OUTDIR)/CLI_Guide.pdf

GUIDE_ADMIN_LIN_PATH := ../resources/documentation/admin-lin
GUIDE_ADMIN_LIN_PDF := $(OUTDIR)/Admin_Guide_Linux.pdf

GUIDE_ADMIN_WIN_PATH := ../resources/documentation/admin-win
GUIDE_ADMIN_WIN_PDF := $(OUTDIR)/Admin_Guide_Windows.pdf

GUIDE_DCC_PATH := ../resources/documentation/dcc-guide
GUIDE_DCC_PDF := $(OUTDIR)/DCC_Guide.pdf

GUIDE_LICENSE_SERVER_PATH := ../resources/documentation/license-server
GUIDE_LICENSE_SERVER_PDF := $(OUTDIR)/License_Server_Guide.pdf

GUIDE_USER_PATH := ../resources/documentation/user-guide
GUIDE_USER_PDF := $(OUTDIR)/User_Guide.pdf

GUIDE_RESTAPI_PATH := ../resources/documentation/restapi-guide
GUIDE_RESTAPI_PDF := $(OUTDIR)/REST_API_Guide.pdf

GUIDE_RELEASE_NOTES_PATH := ../resources/documentation/release-notes
GUIDE_RELEASE_NOTES_PDF := $(OUTDIR)/Release_Notes.pdf

GUIDE_DSPM_PATH := ../resources/documentation/dspm-guide
GUIDE_DSPM_PDF := $(OUTDIR)/DSPM_Guide.pdf

.PHONY: help all clean check install reset
.PHONY: guide-cli guide-admin-lin guide-admin-win guide-dcc guide-license-server guide-user guide-restapi guide-release-notes guide-dspm guides

help: ## Show available targets
	@echo "WeasyPrint-based PDF generation for Markdown documentation"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: $(PDF) ## Convert all markdown files to PDF

$(OUTDIR)/%.pdf: ./%.md | $(OUTDIR)
	@./md2pdf.sh "$<" "$@" "$(CSS)"

$(OUTDIR):
	@mkdir -p $@

# Guide targets
guide-cli: | $(OUTDIR) ## Build CLI Guide PDF
	@echo "==> Building CLI Guide..."
	@./md2pdf.sh "$(GUIDE_CLI_PATH)" "$(GUIDE_CLI_PDF)" -s -v
	@ls -lh $(GUIDE_CLI_PDF)

guide-admin-lin: | $(OUTDIR) ## Build Admin Linux Guide PDF
	@echo "==> Building Admin Linux Guide..."
	@./md2pdf.sh "$(GUIDE_ADMIN_LIN_PATH)" "$(GUIDE_ADMIN_LIN_PDF)" -s -v
	@ls -lh $(GUIDE_ADMIN_LIN_PDF)

guide-admin-win: | $(OUTDIR) ## Build Admin Windows Guide PDF
	@echo "==> Building Admin Windows Guide..."
	@./md2pdf.sh "$(GUIDE_ADMIN_WIN_PATH)" "$(GUIDE_ADMIN_WIN_PDF)" -s -v
	@ls -lh $(GUIDE_ADMIN_WIN_PDF)

guide-dcc: | $(OUTDIR) ## Build DCC Guide PDF
	@echo "==> Building DCC Guide..."
	@./md2pdf.sh "$(GUIDE_DCC_PATH)" "$(GUIDE_DCC_PDF)" -s -v
	@ls -lh $(GUIDE_DCC_PDF)

guide-license-server: | $(OUTDIR) ## Build License Server Guide PDF
	@echo "==> Building License Server Guide..."
	@./md2pdf.sh "$(GUIDE_LICENSE_SERVER_PATH)" "$(GUIDE_LICENSE_SERVER_PDF)" -s -v
	@ls -lh $(GUIDE_LICENSE_SERVER_PDF)

guide-user: | $(OUTDIR) ## Build User Guide PDF
	@echo "==> Building User Guide..."
	@./md2pdf.sh "$(GUIDE_USER_PATH)" "$(GUIDE_USER_PDF)" -s -v
	@ls -lh $(GUIDE_USER_PDF)

guide-restapi: | $(OUTDIR) ## Build REST API Guide PDF
	@echo "==> Building REST API Guide..."
	@./md2pdf.sh "$(GUIDE_RESTAPI_PATH)" "$(GUIDE_RESTAPI_PDF)" -s -v
	@ls -lh $(GUIDE_RESTAPI_PDF)

guide-release-notes: | $(OUTDIR) ## Build Release Notes PDF
	@echo "==> Building Release Notes..."
	@./md2pdf.sh "$(GUIDE_RELEASE_NOTES_PATH)" "$(GUIDE_RELEASE_NOTES_PDF)" -s -v
	@ls -lh $(GUIDE_RELEASE_NOTES_PDF)

guide-dspm: | $(OUTDIR) ## Build DSPM Guide PDF
	@echo "==> Building DSPM Guide..."
	@./md2pdf.sh "$(GUIDE_DSPM_PATH)" "$(GUIDE_DSPM_PDF)" -s -v
	@ls -lh $(GUIDE_DSPM_PDF)

guides: guide-cli guide-admin-lin guide-admin-win guide-dcc guide-license-server guide-user guide-restapi guide-release-notes guide-dspm ## Build all guides

install: ## Install Pandoc, fonts, and set up WeasyPrint
	@$(MAKE) check
	@echo ""
	@echo "==> Installing missing components..."
	@if ! command -v pandoc >/dev/null; then \
		echo "Installing Pandoc..."; \
		$(APTENV) sudo -E apt-get update -yq && \
		$(APTENV) sudo -E apt-get install -yq pandoc; \
	fi
	@if ! fc-list | grep -qi "Lato" || ! fc-list | grep -qi "Source Code Pro" || ! fc-list | grep -qi "DejaVu"; then \
		echo "Installing fonts..."; \
		if ! fc-list | grep -qi "Lato" || ! fc-list | grep -qi "DejaVu"; then \
			$(APTENV) sudo -E apt-get update -yq 2>/dev/null || true; \
			$(APTENV) sudo -E apt-get install -yq fonts-lato fonts-dejavu 2>/dev/null || true; \
		fi; \
		if ! fc-list | grep -qi "Source Code Pro"; then \
			if [ ! -d /tmp/fonts/source-code-pro ]; then \
				mkdir -p /tmp/fonts; \
				git clone --depth 1 -q https://github.com/adobe-fonts/source-code-pro.git /tmp/fonts/source-code-pro 2>/dev/null; \
			fi; \
			sudo mkdir -p /usr/share/fonts/truetype/source-code-pro; \
			sudo cp /tmp/fonts/source-code-pro/TTF/*.ttf /usr/share/fonts/truetype/source-code-pro/; \
			sudo fc-cache -f; \
			rm -rf /tmp/fonts; \
		fi; \
		echo "✅ Fonts installed successfully"; \
	fi
	@if [ ! -x venv/bin/weasyprint ]; then \
		echo "Setting up WeasyPrint..."; \
		python3 -m venv venv && venv/bin/pip install -q weasyprint; \
		echo "✅ WeasyPrint ready"; \
	fi
	@echo ""
	@echo "==> Installation complete!"
	@$(MAKE) check

check: ## Check installed versions and fonts
	@echo "==> Installed versions:"
	@if command -v pandoc >/dev/null 2>&1; then \
		pandoc --version | head -n1; \
	else \
		echo "Pandoc: Not installed"; \
	fi
	@if [ -x venv/bin/weasyprint ]; then \
		venv/bin/weasyprint --version 2>/dev/null; \
	else \
		echo "WeasyPrint: Not installed"; \
	fi
	@echo ""
	@echo "==> Fonts:"
	@LATO=$$(fc-list 2>/dev/null | (grep -i "Lato" || true) | wc -l); \
	if [ $$LATO -gt 0 ]; then \
		echo "Lato: ✅ Installed ($$LATO variants)"; \
	else \
		echo "Lato: ❌ Not installed (run 'make install')"; \
	fi
	@SCP=$$(fc-list 2>/dev/null | (grep -i "Source Code Pro" || true) | wc -l); \
	if [ $$SCP -gt 0 ]; then \
		echo "Source Code Pro: ✅ Installed ($$SCP variants)"; \
	else \
		echo "Source Code Pro: ❌ Not installed (run 'make install')"; \
	fi
	@DJV=$$(fc-list 2>/dev/null | (grep -i "DejaVu" || true) | wc -l); \
	if [ $$DJV -gt 0 ]; then \
		echo "DejaVu: ✅ Installed ($$DJV variants)"; \
	else \
		echo "DejaVu: ❌ Not installed (run 'make install')"; \
	fi

clean: ## Remove generated files
	@rm -rf $(OUTDIR)
	@echo "✅ Cleaned"

reset: clean ## Remove all installed components (Pandoc, fonts, venv) for complete cleanup
	@echo "WARNING: This will remove Pandoc, fonts, and venv!"
	@echo "Press Ctrl+C within 5 seconds to cancel..."
	@sleep 5
	@echo ""
	@echo "==> Removing WeasyPrint venv..."
	@rm -rf venv
	@echo "==> Removing Pandoc..."
	@sudo apt-get remove -y pandoc 2>/dev/null || echo "Pandoc not installed via apt"
	@echo "==> Removing Lato font..."
	@sudo apt-get remove -y fonts-lato 2>/dev/null || echo "Lato not installed via apt"
	@echo "==> Removing Source Code Pro font..."
	@sudo rm -rf /usr/share/fonts/truetype/source-code-pro
	@sudo fc-cache -f 2>/dev/null || true
	@echo ""
	@echo "✅ Reset complete! Run 'make check' to verify."
