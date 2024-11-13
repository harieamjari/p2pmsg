all:

push:
	git add . && git commit -S && cat ~/key1 | \
		termux-clipboard-set && git push $(f)

restore:
	git restore linux macos windows ios
