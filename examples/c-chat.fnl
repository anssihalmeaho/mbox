
ns main

import chat

main = proc()
	call(chat.run
		'clientC'
		'localhost:9907'
		list('localhost:9905' 'localhost:9906')
		list('a-box' 'b-box')
		'c-box'
	)
end

endns

