
ns mbox

trace-on = false

new = proc(own-name own-addr peer-addrs)
	import stdvar
	import stddbc
	import stdfu
	import stdrpc
	import lens
	import stdpp
	import mbpeers

	generate-id = proc()
		import stdstr
		import stdos
		import stdbytes

		ok err out errout = call(stdos.exec 'uuidgen'):
		call(stddbc.assert ok sprintf('%v (%v)' err errout))
		call(stdstr.strip call(stdbytes.string out))
	end
	own-id = call(generate-id)

	lbox = call(stdvar.new map()) # box-id -> channel
	nsbox = call(stdvar.new map()) # box-name -> box-id

	ob = call(mbpeers.new)
	add-peer-with-mboxes = get(ob 'add-peer-with-mboxes')
	add-mbox             = get(ob 'add-mbox')
	get-proxy-for-mbox   = get(ob 'get-proxy-for-mbox')
	get-all              = get(ob 'get-all')
	get-proxies          = get(ob 'get-proxies')

	join-peer = proc(peer-addr)
		px = call(stdrpc.new-proxy peer-addr)
		msg = list('join' own-name own-id own-addr)
		ok err resp = call(stdrpc.rcall px 'mbox-man' msg):
		if(ok
			call(proc()
				peer-id peer-name rec-addr box-ids peer-ns = resp:
				call(add-peer-with-mboxes peer-name rec-addr peer-id px box-ids)
				call(stdvar.change nsbox func(nsval)
					call(stdfu.write-all nsval peer-ns)
				end)
			end)
			'skip'
		)
	end
	call(stdfu.proc-apply peer-addrs join-peer)

	peer-listener = proc(msg)
		if(trace-on
			print(sprintf('    RECEIVED: %v' msg))
			'skip'
		)
		case(head(msg)
			'join'
			call(proc()
				peer-name peer-id peer-addr = rest(msg):
				px = call(stdrpc.new-proxy peer-addr)
				call(add-peer-with-mboxes peer-name peer-addr peer-id px list())
				list(
					own-id
					own-name own-addr
					keys(call(stdvar.value lbox))
					call(stdvar.value nsbox)
				)
			end)

			'reg'
			call(proc()
				rpeer-id new-box-id = rest(msg):
				call(add-mbox rpeer-id new-box-id)
				'ok'
			end)

			'name'
			call(proc()
				_ mbox-name mbox-id = rest(msg): # could check peer-id...
				upd-ok upd-err _ = call(stdvar.change nsbox
					func(prev)
						call(lens.set-to list(mbox-name) prev mbox-id)
					end
				):
				call(stddbc.assert upd-ok upd-err)
			end)

			'send'
			call(proc()
				_ mbox-id content = rest(msg): # could check peer-id...
				found channel = getl(call(stdvar.value lbox) mbox-id):
				if(found
					#NOTE. this is duplicate part with sendmsg
					call(proc()
						send(channel content map('wait' false))
						list(true '') # should check send return value
					end)
					list(false 'mbox not found')
				)
			end)
		)
	end

	call(proc()
		ok err server = call(stdrpc.new-server own-addr):
		call(stddbc.assert ok err)
		call(stdrpc.register server 'mbox-man' peer-listener)
	end)

	create-mbox = proc(bufsize)
		update-peers = proc(box-id)
			msg = list('reg' own-id box-id)
			call(stdfu.proc-apply call(get-proxies) proc(px)
				ok err resp = call(stdrpc.rcall px 'mbox-man' msg):
				true
			end)
		end

		channel = chan(bufsize)
		mbox-id = call(generate-id)
		upd-ok upd-err _ = call(stdvar.change lbox func(prev) put(prev mbox-id channel) end):
		call(stddbc.assert upd-ok upd-err)
		call(update-peers mbox-id)
		list(true '' mbox-id)
	end

	sendmsg = proc(mbox-id msg)
		found channel = getl(call(stdvar.value lbox) mbox-id):
		if(found
			# send locally
			call(proc()
				send(channel msg map('wait' false))
				list(true '') # should check send return value
			end)

			# send to peer
			call(proc()
				proxy-found proxy = call(get-proxy-for-mbox mbox-id):
				if(proxy-found
					call(proc()
						ext-msg = list('send' own-id mbox-id msg)
						ok err resp = call(stdrpc.rcall proxy 'mbox-man' ext-msg):
						list(ok err)
					end)
					list(false 'mbox not found')
				)
			end)
		)
	end

	recmsg = proc(mbox-id)
		found channel = getl(call(stdvar.value lbox) mbox-id):
		if(found
			recwith(channel map('wait' true))
			list(false 'mbox not found')
		)
	end

	register-with-name = proc(mbox-id mbox-name)
		update-peers = proc()
			msg = list('name' own-id mbox-name mbox-id)
			call(stdfu.proc-apply call(get-proxies) proc(px)
				ok err resp = call(stdrpc.rcall px 'mbox-man' msg):
				true
			end)
		end

		# update local ns first
		upd-ok upd-err _ = call(stdvar.change nsbox
			func(prev)
				call(lens.set-to list(mbox-name) prev mbox-id)
			end
		):
		call(stddbc.assert upd-ok upd-err)
		# then peer ns's
		call(update-peers)
		true
	end

	id-by-name = proc(mbox-name)
		getl(call(stdvar.value nsbox) mbox-name)
	end

	contents = proc()
		map(
			'local'  call(stdvar.value lbox)
			'ns'     call(stdvar.value nsbox)
			'global' call(get-all)
		)
	end

	all-names = proc()
		call(stdvar.value nsbox)
	end

	map(
		'create-mbox'        create-mbox
		'sendmsg'            sendmsg
		'recmsg'             recmsg
		'register-with-name' register-with-name
		'id-by-name'         id-by-name
		'contents'           contents
		'all-names'          all-names
	)
end

endns

