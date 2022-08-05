local basic = basis.requre('basic')

function getsuper(v)
	return getbase(getclass(v))
end

function super()
	return getsuper(basic.getlocal(2, 'self'))
end