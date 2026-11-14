# Engine tests (Linux or Mac):  make -C Tests run
CXX ?= g++
CXXFLAGS = -std=c++98 -O2 -Wall -Wextra
SRC = ../Source/Engine/Engine.cpp ../Source/Engine/Wav.cpp ../Source/Engine/Export.cpp ../Source/Engine/Master.cpp

engine_test: engine_test.cpp $(SRC) ../Source/Engine/*.h
	$(CXX) $(CXXFLAGS) engine_test.cpp $(SRC) -o $@

run: engine_test
	mkdir -p renders
	./engine_test renders

asan:
	$(CXX) -std=c++98 -g -O1 -fsanitize=address,undefined engine_test.cpp $(SRC) -o engine_test_asan
	./engine_test_asan

clean:
	rm -rf engine_test engine_test_asan renders

.PHONY: run asan clean
