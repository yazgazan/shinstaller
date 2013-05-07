
all:
	@echo "Compiling ..."
	@make -C src > /dev/null
	@cp -f src/a.out a.out > /dev/null
	@echo "Generating ..."
	@../embeder.sh
	@cp test.out.sh test/

clean:
	@echo "Cleaning ..."
	@rm -f a.out src/a.out
	@rm -f test.out.sh
	@rm -rf test/*

re: clean all

