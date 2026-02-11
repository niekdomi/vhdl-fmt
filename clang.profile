[settings]
os=Linux
arch=x86_64
compiler=clang
compiler.version=21
compiler.cppstd=23

[conf]
tools.cmake.cmaketoolchain:generator=Ninja
tools.build:compiler_executables={"c": "clang", "cpp": "clang++"}
