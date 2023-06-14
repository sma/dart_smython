run-coverage:
	@dart run coverage:test_with_coverage
	@if which -s genhtml ; then \
		genhtml -q coverage/lcov.info -o coverage/html ; \
	else \
		echo "genhtml not found, please 'brew install lcov'" ; \
	fi
	@open coverage/html/index.html
