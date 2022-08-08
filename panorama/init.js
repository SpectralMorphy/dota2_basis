"use strict";

(() => {
	let basis = GameUI.CustomUIConfig().basis
	if(!basis){
		basis = {
			modules: {},
		}
		GameUI.CustomUIConfig().basis = basis
	}

	basis.imprt = (module) => {
		return basis.modules[module]
	}

	basis.exprt = (module, t) => {
		basis.modules[module] = t
	}

	let _state
	let onStateCallbacks = {}

	let basic = {
		fd: (...args) => {
			return args.find(v => v != undefined)
		},

		dget: (source, key, ...args) => {
			if(key == undefined){
				return source
			} else {
				return basic.dget(source[key], ...args.slice(1))
			}
		},

		dgos: (target, key, def, ...args) => {
			let val = target[key]
			let last = (args.length == 0)
			if(!val){
				val = last ? def : {}
				target[key] = val
			}
			return last ? val : basic.dgos(val, def, ...args.slice(1))
		},

		dlet: (...args) => {
			let [f] = args.splice(-1, 1)
			let v = basic.dget(...args)
			if(v != undefined){
				f(v)
			}
		},

		loc: (key, def) => {
			let str = $.Localize(key)
			if(key == str){
				return def || ''
			}
			return str
		},

		backward: (a, callback) => {
			a.slice().reverse().forEach(callback)
		},

		doDbgPrint: false,

		dbgPrint: (msg) => {
			if(basic.doDbgPrint) $.Msg(msg)
		},

		getHud: () => {
			let hud = $.GetContextPanel()
			while(hud.GetParent()) hud = hud.GetParent()
			return hud 
		},

		onState: (state, callback) => {
			let callbacks = basic.dgos(onStateCallbacks, state, [])
			callbacks.push(callback)
		},

		matchSelector: (panel, selector) => {
			return selector.split(',').some(selector => {
				let allowParent = false
				return selector.match(/[#.\w]+/g).reverse().every(temp => {
					while(true){
						if(!panel) return false
						let ok = temp.match(/^[^#.]+|[#.][^#.]+/g).every(basic => {
							let name = basic.slice(1)
							switch(basic[0]){
								case '#': return panel.id == name
								case '.': return panel.BHasClass(name)
							}
							return panel.paneltype == basic
						})
						if(ok){
							allowParent = true
							return true
						}
						else {
							if(allowParent){
								panel = panel.GetParent()
							} else {
								return false
							}
						}
					}
				})
			})
		},

		applyCSS: (panel, css, recursive) => {
			if(!panel) return

			if(typeof css == 'string'){
				let temps = css.match(/[^{}]+{[^{}]+?}/g)
				css = {}
				temps.forEach(temp => {
					let match = temp.match(/([^{}]+){([^{}]+?)}/)
					let selector = match[1].trim()
					let style = {}
					match[2].match(/[^:]+:[^;]+;/g).forEach(line => {
						let match = line.match(/([^:]+):([^;]+);/)
						style[match[1].trim()] = match[2].trim()
					})
					css[selector] = style
				})
			}
			
			for(let [selector, style] of Object.entries(css)){
				if(basic.matchSelector(panel, selector)){
					basic.applyStyle(panel, style)
				}
			}

			if(basic.fd(recursive, true)){
				panel.Children().forEach(child => basic.applyCSS(child, css))
			}
		},

		applyStyle: (panel, style) => {
			for(let [k, v] of Object.entries(style)){
				panel.style[k] = v
			}
		},

		multiline: class {			
			constructor(parent, id){
				this.panel = $.CreatePanel('Panel', parent, id)
				this.panel.AddClass('BasisMultiline')
				this.panel.style.flowChildren = 'down'
				this.__text = ''
				this.__html = false
			}

			get text(){
				return this.__text
			}
			set text(v){
				this.__text = v.toString()
				this.update()
			}

			get html(){
				return this.__html
			}
			set html(v){
				this.__html = v ? true : false
				this.update()
			}

			update(){
				this.panel.RemoveAndDeleteChildren()
				let lines = this.text.split('\n')

				if(this.html){
					let tags = []
					lines = lines.map(line => {
						let newline = line
						basic.backward(tags, t => newline = t.tag + newline)
						basic.dlet(line.match(/<.+?>/g), s => s.forEach(tag => {
							if(tag[1] == '/'){
								tags.pop()
							} else {
								tags.push({
									tag: tag,
									tagname: tag.match(/\w+/),
								})
							}
						}))
						basic.backward(tags, t => newline += `</${t.tagname}>`)
						return newline
					})
				}

				lines.forEach(line => {
					let label = $.CreatePanel('Label', this.panel, '')
					label.AddClass('BasisMultiline_Line')
					label.html = this.html
					label.text = line
				})
			}
		},
	}

	basis.exprt('basis/basic', basic)

	let setup = basis.imprt('basis/setup') || {}

	setup.showLoading = () => {
		if(Game.GameStateIsBefore(DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP)){
			let pickroot = basic.getHud().FindChildTraverse('PreGame')
			pickroot.style.opacity = 0
			basic.onState(DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP, () => {
				pickroot.style.opacity = 1
			})
		}
	}

	setup.setuping = undefined
	setup.errorText = undefined
	
	let setupCSS = `
		#BasisSetup{
			width: 100%;
			height: 400px;
			vertical-align: center;
			background-color: gradient(linear, 0% 0%, 100% 0%, from(#0002), color-stop(0.2, #0006), color-stop(0.8, #0006), to(#0002));
			opacity: 0;
			transition: opacity 0.3s linear 0s;
		}

		#BasisSetup.Setuping{
			opacity: 1;
		}

		#BasisLoading{
			width: 100%;
			vertical-align: center;
			text-align: center;
			font-size: 60px;
			letter-spacing: 7px;
			color: gradient(linear, 0% 0%, 0% 100%, from(#eee), to(#888));
			text-shadow: 2px 2px 5px 2.0 #000;
			opacity: 1;
		}

		#BasisLoadingError{
			vertical-align: center;
			horizontal-align: center;
			max-height: 100%;
			overflow: clip clip;
			opacity: 0;
		}
		#BasisLoadingError .BasisMultiline_Line{
			font-size: 20px;
			color: white;
		}

		#BasisSetup.Error #BasisLoading{
			opacity: 0;
		}
		#BasisSetup.Error #BasisLoadingError{
			opacity: 1;
		}
	`

	Object.defineProperty(setup, 'setupCSS', {
		configurable: true,
		enumerable: true,
		get: () => setupCSS,
		set: v => {
			setupCSS = v
			basic.applyCSS(setup.root, v)
		}
	})

	basic.dlet(setup.root, p => p.IsValid() && p.DeleteAsync(0))

	basic.onState(DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP, () => {
		let cuiRoot = $.GetContextPanel().GetParent()
		let csetupRoot = cuiRoot.FindChild('CustomUIContainer_GameSetup').FindChild('CustomUIContainer')
		if(csetupRoot) csetupRoot.style.opacity = 0
		let root = setup.root = $.CreatePanel('Panel', cuiRoot, 'BasisSetup')
		let lload = $.CreatePanel('Label', root, 'BasisLoading')
		lload.text = basic.loc('ui_basis_loading', 'LOADING')
		let lerror = new basic.multiline(root, 'BasisLoadingError')
		lerror.html = true
		basic.applyCSS(root, setupCSS)

		GameEvents.Subscribe('cl_basis_setup', t => {
			let issetuping = t.setuping ? true : false
			if(setup.setuping != issetuping){
				root.SetHasClass('Setuping', issetuping)
				if(csetupRoot) csetupRoot.style.opacity = issetuping ? 0 : 1
				setup.setuping = issetuping
			}

			let errorText = (typeof t.setuping == 'string') ? t.setuping : undefined
			if(setup.errorText != errorText){
				if(errorText){
					root.AddClass('Error')
					lerror.text = errorText
				} else {
					root.RemoveClass('Error')
				}
				setup.errorText = errorText
			}

			basic.applyCSS(root, setupCSS)
		})

		GameEvents.SendCustomGameEventToServer('sv_basis_setup', {})
	})

	basis.exprt('basis/setup', setup)

	function think(){
		let state = Game.GetState()
		if(_state != state){
			basic.dlet(onStateCallbacks[state], a => a.forEach(f => f()))
			_state = state
		}

		$.Schedule(0, think)
	}
	think()
})()