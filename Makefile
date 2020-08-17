SRC = cpucercent.cpp
DESTDIR=~
PREFIX=/.local

cpucercent: $(SRC)
	$(CXX) $(SRC) -o $@

.PHONY: clean install

clean:
	rm -f cpucercent $(OBJ)

install: cpucercent
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f cpucercent ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/cpucercent

