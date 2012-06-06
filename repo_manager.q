#!/bin/env qore

%require-our
%enable-all-warnings

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
      if ($.tmpdata) {
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
