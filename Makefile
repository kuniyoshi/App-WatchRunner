all: prepare self sam done

prepare:
	clear

self: watch_runner
	pod2text $< README

sam: sam.pl
	perl sam.pl

done:
	@echo ... at `date +%H:%M:%S`

