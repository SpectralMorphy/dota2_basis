(() => {
	$.Msg('basis init')
	let basis = GameUI.CustomUIConfig().basis = {
		modules: {},
	}

	basis.import = function(module){
		return basis.modules[module]
	}

	basis.export = function(module, t){
		basis.modules[module] = t
	}

	let basic
	let _state
	let onStateCallbacks = {}

	basis.export('basic', {
		dgos: (target, key, def, ...args) => {
			let val = target[key]
			let last = (args.length == 0)
			if(!val){
				val = last ? def : {}
				target[key] = val
			}
			return last ? val : basic.dgos(val, def, ...args.slice(1))
		},

		getHud: () => {
			let hud = $.GetContextPanel()
			while(hud.GetParent()) hud = hud.GetParent()
			return hud 
		},

		onState: (state, callback) => {
			let callbacks = basic.dgos(onStateCallbacks, state, [])
			callbacks.push(callback)
		}
	})

	basic = basic.import('basic')

	function think(){
		$.Schedule(0, think)
		
		let state = Game.GetState()
		if(_state != state){
			onStateCallbacks[state]?.foreach(f => f())
			_state = state
		}
	}
	think()

	// let basic = basis.import
})()