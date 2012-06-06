#!/bin/env qore

%require-our
%enable-all-warnings

# -- 
our $tcount = new Counter();
our $misses = new Counter();

#
# Revisioned is on a per-data structure basis, there is no
# single repo for all; each data structure is encapsulated 
# into its own repo object, complete with 'import', 'checkout',
# 'commit', etc..
#

# -- main Revisioned object
class Revisioned { 
  # -- private class variables
  private $.data, $.revision, $.m, $.tmpdata;

  # -- constructor - also, "import"
  constructor($data) {
    $.m = new Mutex();
    $.data = $data; 
    $.revision = 0;
  }

  # -- thread gets local copy
  checkout() {
    on_exit $.m.unlock();
    $.m.lock();
      return ("data" : $.data, "revision" : $.revision);
  }

  # -- get copy of pure data structure
  export() {
    return $.data;
  }

  # -- update, right now just calls checkout
  update(){
    return $.checkout();
  } 

  # -- commit local copy to global repo
  commit($local,$reduceref) {
    on_exit $.m.unlock();
    $.m.lock();
    # -- fallback, check local revision date against HEAD's revision date
    if ($local.revision == $.revision) {
      $.data = $local.data; 
      $.revision++;
      return True;
    # -- if revision check fails, see if there is a reduce function defined
    } else if ($reduceref != NOTHING) {
      # -- if so, execute reduce function and make it the HEAD, ++ revision number
      $.tmpdata = NOTHING;
      # -- make sure $reduceref doesn't fail
      $.tmpdata = $reduceref($local.data,$.data,gettid());
      if (exists $.tmpdata) {
        #printf("merged!\n%s\n",makeJSONString($.tmpdata));
        $.data = $.tmpdata;
        $.revision++;
        return True;
      # -- if it fails, commit fully fails
      } 
    # -- fully fail commit if revision check fails and there is no reduce function provided
    }
    # -- reached on if revision is stale and no $reduceref is passed
    # -- or if $reduceref fails upon application
    return False;
  }
} 

# -- shared data strucutre.......example still contrived and non-conflicting
our $digraph = ();

# -- created Revisioned object out of raw $digraph
our $digraph_r = new Revisioned($digraph); 

# -- has knowledge or some expectation of data structure pair require resolution
# -- it's a merge (or more generally a reduction) of two data structures into 1
sub reduce($local,$HEAD,$tid) {
  # -- initialize tmpdata with state of HEAD 
  my $tmpdata = $HEAD;
  # -- iterate over local data, add to HEAD anything that's missing
  foreach my $key in (keys $local) {
    if (!exists $tmpdata.$key) {
      $tmpdata.$key = $local.$key; 
    }
  }
  #printf("merged!\n%s\n%s\n%s\n",makeJSONString($local),makeJSONString($HEAD),makeJSONString($tmpdata));
  #printf("merged!\n%s\n",makeJSONString($tmpdata));
  return $tmpdata; 
}

sub run_thread() {
  on_exit $tcount.dec();
  my $id = gettid();
  my $num_threads = num_threads();
  
  # checkout local copy
  my $digraph_l = $digraph_r.checkout();
  # -- construct neighbor list (trivial atm - prev/next node, roll over to 0 when $id+1 > $num_threads)
  my $prev = ($id-1 < 0) ? $num_threads - 1 : $id-1;
  my $next = ($id+1 > $num_threads) ? 0 : $id+1;
  # attempt to add node (nn == tid), neighbor defs
  my $newnodes = ('neighbors' : ($prev,$next));
  # insert new node(s) to local copy of digraph
  $digraph_l.data.$id = $newnodes;
  # attempt commit, repeat construction and insertion until commit succeeds 
  while (!($digraph_r.commit($digraph_l,\reduce()))) {
    # count misses
    $misses.inc();
    # update local copy of digraph
    $digraph_l = $digraph_r.update();
    # insert new node(s) to local copy of graph
    $digraph_l.data.$id = $newnodes;
  }
  $digraph_l = $digraph_r.update();
}

for (my $i = 0; $i < 100; $i++) {
  $tcount.inc();
  background run_thread();
}

$tcount.waitForZero();
printf("%s\nmisses: %s\n",makeJSONString($digraph_r.export()),$misses.getCount());
