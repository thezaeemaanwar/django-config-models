.PHONY: clean compile_translations coverage docs dummy_translations extract_translations \
	fake_translations help pull_translations push_translations quality requirements test test-all validate

.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

clean: ## remove generated byte code, coverage reports, and build artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	coverage erase
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

compile_translations: ## compile translation files, outputting .po files for each supported language
	./manage.py compilemessages

coverage: clean ## generate and view HTML coverage report
	py.test --cov-report html
	$(BROWSER) htmlcov/index.html

docs: ## generate Sphinx HTML documentation, including API docs
	tox -e docs
	$(BROWSER) docs/_build/html/index.html

dummy_translations: ## generate dummy translation (.po) files
	cd config_models && i18n_tool dummy

extract_translations: ## extract strings to be translated, outputting .mo files
	./manage.py makemessages -l en -v1 -d django
	./manage.py makemessages -l en -v1 -d djangojs

fake_translations: extract_translations dummy_translations compile_translations ## generate and compile dummy translation files

pip-compile: ## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	pip install -q pip-tools
	pip-compile --upgrade -o requirements/base.txt requirements/base.in
	pip-compile --upgrade -o requirements/dev.txt requirements/dev.in
	pip-compile --upgrade -o requirements/doc.txt requirements/doc.in
	pip-compile --upgrade -o requirements/quality.txt requirements/quality.in
	pip-compile --upgrade -o requirements/test.txt requirements/base.in requirements/test.in
	pip-compile --upgrade -o requirements/travis.txt requirements/travis.in
	# Let tox control the Django version for tests
	sed '/^[d|D]jango==/d' requirements/test.txt > requirements/test.tmp
	mv requirements/test.tmp requirements/test.txt

pull_translations: ## pull translations from Transifex
	tx pull -a

push_translations: ## push source translation files (.po) from Transifex
	tx push -s

quality: ## check coding style with pycodestyle and pylint
	tox -e quality

requirements: ## install development environment requirements
	pip install -qr requirements/dev.txt --exists-action w
	pip-sync requirements/base.txt requirements/dev.txt requirements/private.* requirements/test.txt

test: clean ## run tests in the current virtualenv
	py.test

test-all: ## run tests on every supported Python/Django combination
	tox -e quality
	tox

validate: quality test ## run tests and quality checks
