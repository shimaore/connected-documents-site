
build/build.js: build/main.js build/db.js build/views.js
	mkdir -p build
	component build -s site

build/%.js: client/%.coffee.md
	coffee -c -o build $<

test: build/build.js
	cp $< $@

push: test
	cd test && couchapp pushdocs test/ https://b-sensory.com/public/store

clean:
	rm -f build/build.js test/build.js
