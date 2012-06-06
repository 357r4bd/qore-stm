#!/bin/env qore

# this is an experimental implemenation of a transaction flow
# iterator

%require-our
%enable-all-warnings

# -- 
our $tcount = new Counter();

our $num_resources = 100;
our $chance_resource = 5; # e.g., 10 means 10%
our $chance_happens_after = 10; # e.g., 10 means 10%
our $num_threads = 16;

# --
our $task_graph = (); # used to output task digraph at the end for graphviz

# -- given transaction with index i on thread j, assign up to N-1
# -- transactions (one from up to all other threads), with an index
# -- of at least 1 less than i

sub get_happens_after ($thread_id,$transaction_id) {
  my $happens_after = ();
  # -- makes explicit what is implied, i.e., the order of transactions on a single thread
  #if ($transaction_id > 0) {
  #    push $happens_after, $thread_id + "." + ($transaction_id - 1);
  #}
  for (my $i = 1; $i <= num_threads(); $i++) {
    # -- chance must be right, thread_id can't be same as $i (this is already implied), and trans_id can't be 0 bc of $trans_id - 1 thing
    if (rand() % 100 < ($chance_happens_after-1) && $i != $thread_id && $transaction_id > 0) {
      # id needs to be transaction id, not thread, i.e.
      push $happens_after, $i + "." + ($transaction_id - 1);
    }
  } 
  return $happens_after;
}

sub get_resources () {
  my $resources = ();
  for (my $i = 0; $i < $num_resources; $i++) {
    if (rand() % 100 < ($chance_resource - 1)) {
      push $resources, $i; 
    }
  }
  return $resources;
}

sub next_transaction ($thread_id,$transaction_id) {
  my $resources = get_resources($thread_id,$transaction_id); 
  my $happens_after = get_happens_after($thread_id,$transaction_id); 
  my $t = ("thread_id" : $thread_id,
           "transaction_id" : $transaction_id,
           "resources" : $resources,
           "happens_after" : $happens_after);
  return $t;
}

# -- spawn does, among other things, creates a number of transactions
# -- to be executed (in order, assumed) on the same thread that also
# -- have with it associated resources (thereby setting up the conflict)
# -- and a set of transactions in other threads with which it posses a
# -- 'happens after' relationship - the "dual" of a 'happens before'
sub spawn () {
  on_exit $tcount.dec();
  my $latest_transaction_id = 0;
  my $thread_id = gettid();
  my $tasks = ();

# -- for now, just iterate 5 times
  for (my $i=0;$i<5;$i++) {
    my $transaction = next_transaction($thread_id,$latest_transaction_id++); 
    #-- equivalent of Data::Dumper
    #printf("%s\n",makeJSONString($transaction));
    $tasks{$transaction."thread_id" + "." + $transaction."transaction_id"} = $transaction."happens_after";
  }
  $task_graph.$thread_id = $tasks;
}

# -- this is where the main spawn function is called
for (my $i=0;$i<16; $i++) {
  $tcount.inc();
  background spawn();
}

$tcount.waitForZero();

# -- output to graphviz

#printf("%s\n",makeFormattedJSONString($task_graph));
printf("digraph task_graph {\n");
foreach my $thread in (keys $task_graph) {
  printf("subgraph { %s }\n",join( '->', reverse(keys $task_graph{$thread})));
  foreach my $i in (keys $task_graph{$thread}) {
    foreach my $j in ($task_graph{$thread}{$i}) {
      printf("%s -> %s\n",$i,$j);
    }
  }
}
printf("}\n");
