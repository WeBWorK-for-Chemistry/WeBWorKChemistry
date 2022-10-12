WeBWorK can't do unit tests because of dependencies on a running copy of webwork.  (A future version of WeBWorK will be able to do unit tests.)  Therefore, the test file (*.t extension) won't work.

However, you can add these PGML files as homework problems in a set and view them.  There are no questions and answers, but a series of tests is run to see that the expected values match the values that the subroutines generate when given a string input.
