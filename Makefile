cpuSRC=cpupercentServer.cpp percentgraph/percentgraphServer.hpp
netSRC=networkServer.cpp percentgraph/percentgraphServer.hpp
DESTDIR=~
PREFIX=/.local

all: cpupercentServer networkServer

cpupercentServer: $(cpuSRC)
	$(CXX) $(cpuSRC) -o $@ --std=c++17

networkServer: $(netSRC)
	$(CXX) $(netSRC) -o $@ --std=c++17

.PHONY: clean install all

clean:
	rm -f networkServer cpupercentServer $(OBJ)

install: all
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f cpupercentServer networkServer ${DESTDIR}${PREFIX}/bin
	#chown nobody:nogroup ${DESTDIR}${PREFIX}/bin/cpupercentServer ${DESTDIR}${PREFIX}/bin/networkServer
	chmod 755 ${DESTDIR}${PREFIX}/bin/cpupercentServer ${DESTDIR}${PREFIX}/bin/networkServer
