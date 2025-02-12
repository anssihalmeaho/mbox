
ns chat

run = proc(own-name own-addr peers-lst other-boxes own-box-name)
	import mbox
	import stddbc
	import stdfu
	import stdio

	mb = call(mbox.new own-name own-addr peers-lst)
	create-mbox = get(mb 'create-mbox')
	sendmsg = get(mb 'sendmsg')
	recmsg = get(mb 'recmsg')
	register-with-name = get(mb 'register-with-name')
	id-by-name = get(mb 'id-by-name')
	contents = get(mb 'contents')
	all-names = get(mb 'all-names')

	receiver = proc(rbox me)
		while(true
			call(proc()
				_ val = call(recmsg rbox):
				print('\n -> ' val)
				rbox
			end)
			me
			'whatever'
		)
	end

	send-to-peer = proc(boxname message)
		target = call(id-by-name boxname)
		target-found target-box = target:
		if(target-found
			call(sendmsg target-box message)
			'target not found'
		)
	end

	ok err box = call(create-mbox 10):
	call(stddbc.assert ok err)
	spawn(call(receiver box own-name))
	call(register-with-name box own-box-name)

	send-to-others = proc(message)
		call(stdfu.proc-apply other-boxes proc(boxname)
			call(send-to-peer boxname message)
		end)
	end

	call(stdio.printline 'press exit or quit to quit to exit from client')
	call(proc(do-exit)
		while(not(do-exit)
			call(proc()
				call(stdio.printf '%s> ' own-name)
				input = call(stdio.readinput)
				case(input
					'exit' true
					'quit' true
					''     false
					call(proc()
						call(send-to-others input)
						false
					end)
				)
			end)
			'bye'
		)
	end false)
end

endns

