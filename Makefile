
push: test push.coffee.md
	coffee push.coffee.md

build/build.js: index.js build/main.js build/db.js build/views.js
	mkdir -p build
	component build -s site

build/%.js: client/%.coffee.md
	coffee -c -o build $<

test: build/build.js
	cp $< $@

clean:
	rm -f build/build.js test/build.js
