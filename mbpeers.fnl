
ns mbpeers

new = proc()
	import stdvar
	import lens
	import stdfu
	import stdpp

	ds = call(stdvar.new map(
		'peers' map()  # peer-id -> peer-object
		'gbox'  map()  # mbox-id -> proxy
		'links' list() # list of pairs: peer-id/mbox-id
	))

/*
- find out if peer-id is found in peers
if it is found:
- del peer from peers
- find all mbox-ids related to that peer-id
	-> remove those mbox-ids from gbox
	-> remove those pairs (by filter ?) from links
and then in any case add new peer/mboxes
*/

	find-peer = func(peers-by-id peername peeraddr)
		matched = call(stdfu.filter peers-by-id func(_ value)
			and(
				eq(get(value 'name') peername)
				eq(get(value 'addr') peeraddr)
			)
		end)
		matched-peer-ids = keys(matched)
		if( lt(len(matched-peer-ids) 2)
			'ok'
			error(sprintf('unexpected amount of peers: %v' matched-peer-ids))
		)
		if(empty(matched)
			list(false '')
			list(true head(matched-peer-ids))
		)
	end

	remove-peer = func(store old-peer-id)
		call(stdfu.chain store list(
			# del peer from peers
			func(v)
				_ v2 = call(lens.del-from list('peers' old-peer-id) v):
				v2
			end
			# remove those mbox-ids from gbox
			func(v)
				old-links = get(v 'links')
				matched-links = call(stdfu.filter old-links func(pair)
					peer-id _ = pair:
					eq(old-peer-id peer-id)
				end)
				old-mbox-ids = call(stdfu.apply matched-links func(pair) last(pair) end)
				old-gbox = get(v 'gbox')
				new-gbox = call(stdfu.filter old-gbox func(key value) not(in(old-mbox-ids key)) end)
				call(lens.set-to list('gbox') v new-gbox)
			end
			# remove those pairs from links
			func(v)
				old-links = get(v 'links')
				new-links = call(stdfu.filter old-links func(pair)
					peer-id _ = pair:
					not(eq(old-peer-id peer-id))
				end)
				call(lens.set-to list('links') v new-links)
			end
		))
	end

	# if peer is already found then remove peer and all related mboxes first
	# then add peer and mboxes
	add-peer-with-mboxes = proc(peername peeraddr peer-id proxy mboxes)
		peer-ob = map(
			'name'  peername
			'addr'  peeraddr
			'id'    peer-id
			'proxy' proxy
		)
		ok err _ = call(stdvar.change ds func(store)
			call(stdfu.chain store list(
				# here first removal of possibly existing stuff...
				func(v)
					old-peer-found old-peer-id = call(find-peer get(v 'peers') peername peeraddr):
					if(old-peer-found
						call(remove-peer v old-peer-id)
						v
					)
				end
				# add to peers
				func(v)
					call(lens.set-to list('peers' peer-id) v peer-ob)
				end
				# add all mboxes to gbox
				func(v)
					call(stdfu.loop func(boxid cum)
						call(lens.set-to list('gbox' boxid) cum proxy)
					end mboxes v)
				end
				# add links related to all mboxes
				func(v)
					old-links = get(v 'links')
					new-links = call(stdfu.loop func(boxid cum)
						append(cum list(peer-id boxid))
					end mboxes old-links)
					call(lens.set-to list('links') v new-links)
				end
			))
		end):
		list(ok err)
	end

	add-mbox = proc(peer-id mbox-id)
		ok err _ = call(stdvar.change ds func(store)
			peer-found peer-ob = call(lens.get-from list('peers' peer-id) store):
			if(peer-found
				call(func()
					# first update gbox
					proxy = get(peer-ob 'proxy')
					store2 = call(lens.set-to list('gbox' mbox-id) store proxy)

					# then links
					old-links = get(store 'links')
					new-link = list(peer-id mbox-id)
					matched-links = call(stdfu.filter old-links func(pair)
						eq(pair new-link)
					end)
					new-links = if(empty(matched-links)
						append(old-links new-link)
						old-links
					)
					call(lens.set-to list('links') store2 new-links)
				end)
				error(sprintf('peer not found: ' peer-id))
			)
		end):
		list(ok err)
	end

	get-proxy-for-mbox = proc(mbox-id)
		stored = call(stdvar.value ds)
		call(lens.get-from list('gbox' mbox-id) stored)
	end

	get-all = proc()
		call(stdvar.value ds)
	end

	get-proxies = proc()
		peer-obs = vals(get(call(stdvar.value ds) 'peers'))
		call(stdfu.apply peer-obs func(pob) get(pob 'proxy') end)
	end

	map(
		'add-peer-with-mboxes' add-peer-with-mboxes
		'add-mbox'             add-mbox
		'get-proxy-for-mbox'   get-proxy-for-mbox
		'get-all'              get-all
		'get-proxies'          get-proxies
	)
end

test = proc()
	import stddbc
	import stdpp
	import stdfu
	import sure

	ob = call(new)
	add-peer-with-mboxes = get(ob 'add-peer-with-mboxes')
	add-mbox             = get(ob 'add-mbox')
	get-proxy-for-mbox   = get(ob 'get-proxy-for-mbox')
	get-all              = get(ob 'get-all')
	get-proxies          = get(ob 'get-proxies')

	assure-stuff = proc(assumed-proxy not-assumed-mboxes assumed-mboxes)
		call(stdfu.proc-apply assumed-mboxes proc(mbox-id)
			found proxy = call(get-proxy-for-mbox mbox-id):
			call(stddbc.assert found sprintf('proxy should be found (%v)' mbox-id))
			call(stddbc.assert eq(assumed-proxy proxy) sprintf('unexpected proxy (%v)' proxy))
		end)
		call(stdfu.proc-apply not-assumed-mboxes proc(mbox-id)
			found _ = call(get-proxy-for-mbox mbox-id):
			call(stddbc.assert not(found) sprintf('should not be found: %v' mbox-id))
		end)
	end

	call(sure.ok call(add-peer-with-mboxes 'peer1' 'addr1' '1' 'proxy1' list('mb1' 'mb2')))
	call(sure.ok call(add-peer-with-mboxes 'peer2' 'addr2' '2' 'proxy2' list('mb21' 'mb22')))

	call(assure-stuff 'proxy1' list('no-mb' 'mb10') list('mb1' 'mb2'))
	call(assure-stuff 'proxy2' list('no-mb' 'mb10') list('mb21' 'mb22'))

	call(sure.ok call(add-peer-with-mboxes 'peer1' 'addr1' '1x' 'proxy1x' list('mb-new-1' 'mb-new-2')))

	call(assure-stuff 'proxy1x' list('mb1' 'mb2') list('mb-new-1' 'mb-new-2'))
	call(assure-stuff 'proxy2' list() list('mb21' 'mb22'))

	call(sure.ok call(add-mbox '2' 'MB2'))
	call(assure-stuff 'proxy2' list() list('mb21' 'mb22' 'MB2'))

	import stdset
	proxies-now = call(stdset.list-to-set call(stdset.newset) call(get-proxies))
	assumed-proxies = call(stdset.list-to-set call(stdset.newset) list('proxy2' 'proxy1x'))
	call(stddbc.assert call(stdset.equal proxies-now assumed-proxies) sprintf('unexpected proxies: %v' proxies-now))

	call(stdpp.pprint call(get-all))
	'PASSED'
end

endns

