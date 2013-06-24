#Author: Chunis Deng (chunchengfh at gmail.com)
LUALIB := /usr/lib/lua/5.1

all: 
	g++ -shared -o blowfish.so blowfish/blowfish/*.cpp
	gcc -shared -o stringconv.so luastringconv/*.c

install:
	cp blowfish.so $(LUALIB)
	cp stringconv.so $(LUALIB)

clean:
	rm -f blowfish.so
	rm -f stringconv.so
