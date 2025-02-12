
ns main

import chat

main = proc()
	call(chat.run
		'clientA'
		'localhost:9905'
		list('localhost:9907' 'localhost:9906')
		list('b-box' 'c-box')
		'a-box'
	)
end

endns

