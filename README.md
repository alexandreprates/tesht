# _teSHt_

Microframework for functional tests in Bash scripts

## How to use

Add _tesht_ to your bash project as a submodule [doc here](https://github.blog/2016-02-01-working-with-submodules/)

Write your tests using standard _tesht_ assertions

Run all tests using the docker container

Be happy

### Assertions

```bash
# when command has no stdout, test the exitcode
test mkdir -p /tmp/foo/bar
assert_success

# also test if dir has created
assert_dir /tmp/foo/bar

# cd has no output
test cd /tmp/foo/bar
assert_success

# but we can test if current dir has changed
test pwd
assert_stdout /tmp/foo/bar

# if you need to test an error
test cd /no_dir
assert_fail
# You can also use a regexp to create a match
assert_stderr "cd: /no_dir: [Nn]o such file or directory"
```

### Creating tests files

 Create a `.tsh` file with the assertions on test dir (./tests)
 
### Running tests

Run the tests under docker container

with bash 3

```bash
docker run -it --rm -v `pwd`:/`basename $(pwd)` -w /`basename $(pwd)` bash:3 ./tesht.sh "tests/*.tsh"
```

or 4

```bash
docker run -it --rm -v `pwd`:/`basename $(pwd)` -w /`basename $(pwd)` bash:4 ./tesht.sh "tests/*.tsh"
```
