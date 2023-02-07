# teSHT

_teSHt_ is a microframework for functional testing in Bash scripts. With its simple and intuitive assertions, you can easily verify the behavior of your scripts.

## Getting Started

1. Add _teSHt_ to your project as a submodule by following the instructions [here](https://github.blog/2016-02-01-working-with-submodules/).

2. Write your tests using the provided assertions.

3. Run all tests using the Docker container.

## Writing Tests

```bash
# Test the creation of a directory
test mkdir -p /tmp/foo/bar
assert_success
assert_dir /tmp/foo/bar

# Test changing to a directory and checking the current directory
test cd /tmp/foo/bar
assert_success
test pwd
assert_stdout /tmp/foo/bar

# Test handling an error
test cd /nonexistent_dir
assert_fail
assert_stderr "cd: /nonexistent_dir: No such file or directory"

# Test the presence of a file
test touch /tmp/foo/bar/test.txt
assert_success
assert_file /tmp/foo/bar/test.txt
````

## Creating Test Files

To create test files with _teSHt_, follow these steps:

1. Create a directory named `tests` in your project, where you will store your test files.

2. In the `tests` directory, create a file with a `.tsh` extension. This file should contain your assertions and tests.

3. For example, the following code tests the creation of a directory:

```bash
# ./test/mkdir.tsh - Test the creation of a directory
test mkdir -p /tmp/foo/bar
assert_success
assert_dir /tmp/foo/bar
```

With these simple steps, you're ready to create your test files with teSHt!

## Running Tests

Running tests with _teSHt_ is easy and flexible. You can run your tests using any version of Bash that you want, simply by using Docker. 

Here's how:

1. Make sure you have Docker installed on your system.

3. Choose the version of Bash you want to run your tests with _teSHt_.

4. Run the following command, replacing `<version>` depending on the version of Bash you want to use:

```bash
$ docker run -it --rm -v `pwd`:/`basename $(pwd)` -w /`basename $(pwd)` bash:<version> ./tesht.sh "tests/*.tsh"
```

teSHt will run all test files with a .tsh extension in the tests directory, and display the results in the terminal.
That's it! You can now run your tests with any version of Bash you want, using Docker and teSHt.


## CI Integration

_teSHt_ can be easily integrated with Continuous Integration (CI) systems, allowing you to automate your testing process.

The tests are executed using the Docker container, and in the case of a failed test scenario, _teSHt_ returns a non-zero exit code, indicating a failure. This exit code can be captured by your CI system, allowing you to immediately detect and address any issues with your code.

To integrate _teSHt_ with your CI system, simply add the `docker run` command to your CI pipeline. This will run the tests every time your code is pushed or a new build is created.

In this way, _teSHt_ helps you ensure that your code always meets the expected standards and specifications, and that any issues are caught and addressed quickly, keeping your development process efficient and streamlined.

