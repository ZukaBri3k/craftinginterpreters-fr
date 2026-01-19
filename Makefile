BUILD_DIR := build
TOOL_SOURCES := tool/pubspec.lock $(shell find tool -name '*.dart')
BUILD_SNAPSHOT := $(BUILD_DIR)/build.dart.snapshot
TEST_SNAPSHOT := $(BUILD_DIR)/test.dart.snapshot

default: book clox jlox

# Run dart pub get on tool directory.
get:
	@ cd ./tool; dart pub get

# Remove all build outputs and intermediate files.
clean:
	@ rm -rf $(BUILD_DIR)
	@ rm -rf gen

# Build the site.
book: $(BUILD_SNAPSHOT)
	@ dart $(BUILD_SNAPSHOT)

# Run a local development server for the site that rebuilds automatically.
serve: $(BUILD_SNAPSHOT)
	@ dart $(BUILD_SNAPSHOT) --serve

$(BUILD_SNAPSHOT): $(TOOL_SOURCES)
	@ mkdir -p build
	@ echo "Compiling Dart snapshot..."
	@ dart --snapshot=$@ --snapshot-kind=app-jit tool/bin/build.dart >/dev/null

# Run the tests for the final versions of clox and jlox.
test: debug jlox $(TEST_SNAPSHOT)
	@- dart $(TEST_SNAPSHOT) clox
	@ dart $(TEST_SNAPSHOT) jlox

# Run the tests for the final version of clox.
test_clox: debug $(TEST_SNAPSHOT)
	@ dart $(TEST_SNAPSHOT) clox

# Run the tests for the final version of jlox.
test_jlox: jlox $(TEST_SNAPSHOT)
	@ dart $(TEST_SNAPSHOT) jlox

# Run the tests for every chapter's version of clox.
test_c: debug c_chapters $(TEST_SNAPSHOT)
	@ dart $(TEST_SNAPSHOT) c

# Run the tests for every chapter's version of jlox.
test_java: jlox java_chapters $(TEST_SNAPSHOT)
	@ dart $(TEST_SNAPSHOT) java

# Run the tests for every chapter's version of clox and jlox.
test_all: debug jlox c_chapters java_chapters compile_snippets $(TEST_SNAPSHOT)
	@ dart $(TEST_SNAPSHOT) all

$(TEST_SNAPSHOT): $(TOOL_SOURCES)
	@ mkdir -p build
	@ echo "Compiling Dart snapshot..."
	@ dart --snapshot=$@ --snapshot-kind=app-jit tool/bin/test.dart clox >/dev/null

# Compile a debug build of clox.
debug:
	@ $(MAKE) -f util/c.make NAME=cloxd MODE=debug SOURCE_DIR=c

# Compile the C interpreter.
clox:
	@ $(MAKE) -f util/c.make NAME=clox MODE=release SOURCE_DIR=c
	@ cp build/clox clox # For convenience, copy the interpreter to the top level.

# Compile the C interpreter as ANSI standard C++.
cpplox:
	@ $(MAKE) -f util/c.make NAME=cpplox MODE=debug CPP=true SOURCE_DIR=c

# Compile and run the AST generator.
generate_ast:
	@ $(MAKE) -f util/java.make DIR=java PACKAGE=tool
	@ java -cp build/java com.craftinginterpreters.tool.GenerateAst \
			java/com/craftinginterpreters/lox

# Compile the Java interpreter .java files to .class files.
jlox: generate_ast
	@ $(MAKE) -f util/java.make DIR=java PACKAGE=lox

run_generate_ast = @ java -cp build/gen/$(1) \
			com.craftinginterpreters.tool.GenerateAst \
			gen/$(1)/com/craftinginterpreters/lox

java_chapters: split_chapters
	@ $(MAKE) -f util/java.make DIR=gen/chap04_analyse PACKAGE=lox

	@ $(MAKE) -f util/java.make DIR=gen/chap05_représentation PACKAGE=tool
	$(call run_generate_ast,chap05_représentation)
	@ $(MAKE) -f util/java.make DIR=gen/chap05_représentation PACKAGE=lox

	@ $(MAKE) -f util/java.make DIR=gen/chap06_analyse PACKAGE=tool
	$(call run_generate_ast,chap06_analyse)
	@ $(MAKE) -f util/java.make DIR=gen/chap06_analyse PACKAGE=lox

	@ $(MAKE) -f util/java.make DIR=gen/chap07_évaluation PACKAGE=tool
	$(call run_generate_ast,chap07_évaluation)
	@ $(MAKE) -f util/java.make DIR=gen/chap07_évaluation PACKAGE=lox

	@ $(MAKE) -f util/java.make DIR=gen/chap08_instructions PACKAGE=tool
	$(call run_generate_ast,chap08_instructions)
	@ $(MAKE) -f util/java.make DIR=gen/chap08_instructions PACKAGE=lox

	@ $(MAKE) -f util/java.make DIR=gen/chap09_contrôle PACKAGE=tool
	$(call run_generate_ast,chap09_contrôle)
	@ $(MAKE) -f util/java.make DIR=gen/chap09_contrôle PACKAGE=lox

	@ $(MAKE) -f util/java.make DIR=gen/chap10_fonctions PACKAGE=tool
	$(call run_generate_ast,chap10_fonctions)
	@ $(MAKE) -f util/java.make DIR=gen/chap10_fonctions PACKAGE=lox

	@ $(MAKE) -f util/java.make DIR=gen/chap11_résolution PACKAGE=tool
	$(call run_generate_ast,chap11_résolution)
	@ $(MAKE) -f util/java.make DIR=gen/chap11_résolution PACKAGE=lox

	@ $(MAKE) -f util/java.make DIR=gen/chap12_classes PACKAGE=tool
	$(call run_generate_ast,chap12_classes)
	@ $(MAKE) -f util/java.make DIR=gen/chap12_classes PACKAGE=lox

	@ $(MAKE) -f util/java.make DIR=gen/chap13_héritage PACKAGE=tool
	$(call run_generate_ast,chap13_héritage)
	@ $(MAKE) -f util/java.make DIR=gen/chap13_héritage PACKAGE=lox

c_chapters: split_chapters
	@ $(MAKE) -f util/c.make NAME=chap14_morceaux MODE=release SOURCE_DIR=gen/chap14_morceaux
	@ $(MAKE) -f util/c.make NAME=chap15_machine MODE=release SOURCE_DIR=gen/chap15_machine
	@ $(MAKE) -f util/c.make NAME=chap16_analyse MODE=release SOURCE_DIR=gen/chap16_analyse
	@ $(MAKE) -f util/c.make NAME=chap17_compilation MODE=release SOURCE_DIR=gen/chap17_compilation
	@ $(MAKE) -f util/c.make NAME=chap18_types MODE=release SOURCE_DIR=gen/chap18_types
	@ $(MAKE) -f util/c.make NAME=chap19_chaînes MODE=release SOURCE_DIR=gen/chap19_chaînes
	@ $(MAKE) -f util/c.make NAME=chap20_tables MODE=release SOURCE_DIR=gen/chap20_tables
	@ $(MAKE) -f util/c.make NAME=chap21_variables MODE=release SOURCE_DIR=gen/chap21_variables
	@ $(MAKE) -f util/c.make NAME=chap22_variables MODE=release SOURCE_DIR=gen/chap22_variables
	@ $(MAKE) -f util/c.make NAME=chap23_sauts MODE=release SOURCE_DIR=gen/chap23_sauts
	@ $(MAKE) -f util/c.make NAME=chap24_appels MODE=release SOURCE_DIR=gen/chap24_appels
	@ $(MAKE) -f util/c.make NAME=chap25_fermetures MODE=release SOURCE_DIR=gen/chap25_fermetures
	@ $(MAKE) -f util/c.make NAME=chap26_ramasse-miettes MODE=release SOURCE_DIR=gen/chap26_ramasse-miettes
	@ $(MAKE) -f util/c.make NAME=chap27_classes MODE=release SOURCE_DIR=gen/chap27_classes
	@ $(MAKE) -f util/c.make NAME=chap28_méthodes MODE=release SOURCE_DIR=gen/chap28_méthodes
	@ $(MAKE) -f util/c.make NAME=chap29_superclasses MODE=release SOURCE_DIR=gen/chap29_superclasses
	@ $(MAKE) -f util/c.make NAME=chap30_optimisation MODE=release SOURCE_DIR=gen/chap30_optimisation

cpp_chapters: split_chapters
	@ $(MAKE) -f util/c.make NAME=cpp_chap14_morceaux MODE=release CPP=true SOURCE_DIR=gen/chap14_morceaux
	@ $(MAKE) -f util/c.make NAME=cpp_chap15_machine MODE=release CPP=true SOURCE_DIR=gen/chap15_machine
	@ $(MAKE) -f util/c.make NAME=cpp_chap16_analyse MODE=release CPP=true SOURCE_DIR=gen/chap16_analyse
	@ $(MAKE) -f util/c.make NAME=cpp_chap17_compilation MODE=release CPP=true SOURCE_DIR=gen/chap17_compilation
	@ $(MAKE) -f util/c.make NAME=cpp_chap18_types MODE=release CPP=true SOURCE_DIR=gen/chap18_types
	@ $(MAKE) -f util/c.make NAME=cpp_chap19_chaînes MODE=release CPP=true SOURCE_DIR=gen/chap19_chaînes
	@ $(MAKE) -f util/c.make NAME=cpp_chap20_tables MODE=release CPP=true SOURCE_DIR=gen/chap20_tables
	@ $(MAKE) -f util/c.make NAME=cpp_chap21_variables MODE=release CPP=true SOURCE_DIR=gen/chap21_variables
	@ $(MAKE) -f util/c.make NAME=cpp_chap22_variables MODE=release CPP=true SOURCE_DIR=gen/chap22_variables
	@ $(MAKE) -f util/c.make NAME=cpp_chap23_sauts MODE=release CPP=true SOURCE_DIR=gen/chap23_sauts
	@ $(MAKE) -f util/c.make NAME=cpp_chap24_appels MODE=release CPP=true SOURCE_DIR=gen/chap24_appels
	@ $(MAKE) -f util/c.make NAME=cpp_chap25_fermetures MODE=release CPP=true SOURCE_DIR=gen/chap25_fermetures
	@ $(MAKE) -f util/c.make NAME=cpp_chap26_ramasse-miettes MODE=release CPP=true SOURCE_DIR=gen/chap26_ramasse-miettes
	@ $(MAKE) -f util/c.make NAME=cpp_chap27_classes MODE=release CPP=true SOURCE_DIR=gen/chap27_classes
	@ $(MAKE) -f util/c.make NAME=cpp_chap28_méthodes MODE=release CPP=true SOURCE_DIR=gen/chap28_méthodes
	@ $(MAKE) -f util/c.make NAME=cpp_chap29_superclasses MODE=release CPP=true SOURCE_DIR=gen/chap29_superclasses
	@ $(MAKE) -f util/c.make NAME=cpp_chap30_optimisation MODE=release CPP=true SOURCE_DIR=gen/chap30_optimisation

diffs: split_chapters java_chapters
	@ mkdir -p build/diffs
	@ -diff --recursive --new-file nonexistent/ gen/chap04_analyse/com/craftinginterpreters/ > build/diffs/chap04_analyse.diff
	@ -diff --recursive --new-file gen/chap04_analyse/com/craftinginterpreters/ gen/chap05_représentation/com/craftinginterpreters/ > build/diffs/chap05_représentation.diff
	@ -diff --recursive --new-file gen/chap05_représentation/com/craftinginterpreters/ gen/chap06_analyse/com/craftinginterpreters/ > build/diffs/chap06_analyse.diff
	@ -diff --recursive --new-file gen/chap06_analyse/com/craftinginterpreters/ gen/chap07_évaluation/com/craftinginterpreters/ > build/diffs/chap07_évaluation.diff
	@ -diff --recursive --new-file gen/chap07_évaluation/com/craftinginterpreters/ gen/chap08_instructions/com/craftinginterpreters/ > build/diffs/chap08_instructions.diff
	@ -diff --recursive --new-file gen/chap08_instructions/com/craftinginterpreters/ gen/chap09_contrôle/com/craftinginterpreters/ > build/diffs/chap09_contrôle.diff
	@ -diff --recursive --new-file gen/chap09_contrôle/com/craftinginterpreters/ gen/chap10_fonctions/com/craftinginterpreters/ > build/diffs/chap10_fonctions.diff
	@ -diff --recursive --new-file gen/chap10_fonctions/com/craftinginterpreters/ gen/chap11_résolution/com/craftinginterpreters/ > build/diffs/chap11_résolution.diff
	@ -diff --recursive --new-file gen/chap11_résolution/com/craftinginterpreters/ gen/chap12_classes/com/craftinginterpreters/ > build/diffs/chap12_classes.diff
	@ -diff --recursive --new-file gen/chap12_classes/com/craftinginterpreters/ gen/chap13_héritage/com/craftinginterpreters/ > build/diffs/chap13_héritage.diff

	@ -diff --new-file nonexistent/ gen/chap14_morceaux/ > build/diffs/chap14_morceaux.diff
	@ -diff --new-file gen/chap14_morceaux/ gen/chap15_machine/ > build/diffs/chap15_machine.diff
	@ -diff --new-file gen/chap15_machine/ gen/chap16_analyse/ > build/diffs/chap16_analyse.diff
	@ -diff --new-file gen/chap16_analyse/ gen/chap17_compilation/ > build/diffs/chap17_compilation.diff
	@ -diff --new-file gen/chap17_compilation/ gen/chap18_types/ > build/diffs/chap18_types.diff
	@ -diff --new-file gen/chap18_types/ gen/chap19_chaînes/ > build/diffs/chap19_chaînes.diff
	@ -diff --new-file gen/chap19_chaînes/ gen/chap20_tables/ > build/diffs/chap20_tables.diff
	@ -diff --new-file gen/chap20_tables/ gen/chap21_variables/ > build/diffs/chap21_variables.diff
	@ -diff --new-file gen/chap21_variables/ gen/chap22_variables/ > build/diffs/chap22_variables.diff
	@ -diff --new-file gen/chap22_variables/ gen/chap23_sauts/ > build/diffs/chap23_sauts.diff
	@ -diff --new-file gen/chap23_sauts/ gen/chap24_appels/ > build/diffs/chap24_appels.diff
	@ -diff --new-file gen/chap24_appels/ gen/chap25_fermetures/ > build/diffs/chap25_fermetures.diff
	@ -diff --new-file gen/chap25_fermetures/ gen/chap26_ramasse-miettes/ > build/diffs/chap26_ramasse-miettes.diff
	@ -diff --new-file gen/chap26_ramasse-miettes/ gen/chap27_classes/ > build/diffs/chap27_classes.diff
	@ -diff --new-file gen/chap27_classes/ gen/chap28_méthodes/ > build/diffs/chap28_méthodes.diff
	@ -diff --new-file gen/chap28_méthodes/ gen/chap29_superclasses/ > build/diffs/chap29_superclasses.diff
	@ -diff --new-file gen/chap29_superclasses/ gen/chap30_optimisation/ > build/diffs/chap30_optimisation.diff

split_chapters:
	@ dart tool/bin/split_chapters.dart

compile_snippets:
	@ dart tool/bin/compile_snippets.dart

# Generate the XML for importing into InDesign.
xml: $(TOOL_SOURCES)
	@ dart --enable-asserts tool/bin/build_xml.dart

.PHONY: book c_chapters clean clox compile_snippets debug default diffs \
	get java_chapters jlox serve split_chapters test test_all test_c test_java
