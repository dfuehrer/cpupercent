#SRC = cpucercent.cpp
SRC = cpupercent.cpp
DESTDIR=~
PREFIX=/.local

#cpucercent: $(SRC)
cpupercent: $(SRC)
	$(CXX) $(SRC) -o $@

.PHONY: clean install

clean:
	rm -f cpupercent $(OBJ)

#install: cpucercent
install: cpupercent
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f cpupercent ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/cpupercent

