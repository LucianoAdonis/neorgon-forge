.PHONY: test-brief test-collect help install refresh validate new status uninstall

SKILLS := plugins/neorgon-forge/skills
DEST   := $(HOME)/.claude/skills

help:
	@echo "neorgon-forge"
	@echo ""
	@echo "  make install                  symlink skills into ~/.claude/skills"
	@echo "  make install PROJECT=<dir>    symlink into <dir>/.claude/skills instead"
	@echo "  make refresh                  pull, re-link, report drift, validate"
	@echo "  make validate                 check every skill against the house standard"
	@echo "  make validate SKILL=task      check one"
	@echo "  make new NAME=x BUCKET=b PURPOSE='y'   scaffold a new skill"
	@echo "                                buckets: before during after craft"
	@echo "  make status                   what is installed, and from where"
	@echo "  make uninstall                remove the symlinks (leaves the repo alone)"

install:
ifdef PROJECT
	@bash bin/install.sh --project "$(PROJECT)"
else
	@bash bin/install.sh
endif

refresh:
	@bash bin/refresh.sh

validate: test-brief test-collect
ifdef SKILL
	@bash bin/validate.sh "$(SKILL)"
else
	@bash bin/validate.sh
endif

new:
ifndef NAME
	@echo "usage: make new NAME=my-skill BUCKET=during PURPOSE=\"one-line purpose\"" && exit 1
endif
ifndef BUCKET
	@echo "usage: make new NAME=my-skill BUCKET=during PURPOSE=\"one-line purpose\"" && exit 1
endif
ifndef PURPOSE
	@echo "usage: make new NAME=my-skill BUCKET=during PURPOSE=\"one-line purpose\"" && exit 1
endif
	@bash bin/new.sh "$(NAME)" "$(BUCKET)" "$(PURPOSE)"

status:
	@printf '\033[1mSkills in this repo\033[0m\n'
	@for b in $(SKILLS)/*/; do \
		printf '  \033[1m%s\033[0m\n' "$$(basename $$b)"; \
		for d in $$b*/; do printf '    %s\n' "$$(basename $$d)"; done; done
	@printf '\n\033[1mInstalled at %s\033[0m\n' "$(DEST)"
	@for d in $(SKILLS)/*/*/; do \
		n=$$(basename $$d); t="$(DEST)/$$n"; \
		if [ -L "$$t" ]; then printf '  \033[32m✓\033[0m %-12s → %s\n' "$$n" "$$(readlink $$t)"; \
		elif [ -d "$$t" ]; then printf '  \033[33m!\033[0m %-12s (real directory, not a link)\n' "$$n"; \
		else printf '  \033[2m·\033[0m %-12s not installed\n' "$$n"; fi; done

uninstall:
	@for d in $(SKILLS)/*/*/; do \
		n=$$(basename $$d); t="$(DEST)/$$n"; \
		if [ -L "$$t" ]; then rm "$$t"; printf '  removed %s\n' "$$n"; fi; done
	@echo "Restart Claude Code to drop them from the session."

test-collect:  ## exercise closeout/collect.sh: the run it reads, the repos it names
	@bash bin/test-collect.sh

test-brief:  ## exercise brief.sh: multi-run isolation, TSV integrity, the index
	@bash bin/test-brief.sh
