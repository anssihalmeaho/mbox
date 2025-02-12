
ns main

import chat

main = proc()
	call(chat.run
		'clientB'
		'localhost:9906'
		list('localhost:9905' 'localhost:9907')
		list('a-box' 'c-box')
		'b-box'
	)
end

endns

