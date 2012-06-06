#!/bin/env qore

%require-our
%enable-all-warnings

sub alwaysFail() {                                                                                                                                                          
  return False;
} 

my $x = 0;
if (!($x = alwaysFail())) {
  printf("hi, %s\n",$x);
} else {
  printf("hi, %s\n",$x);
}
