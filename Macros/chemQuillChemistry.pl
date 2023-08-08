HEADER_TEXT( MODES(TeX=>'', HTML=><<END_SCRIPT ));
<script>
window.addEventListener('DOMContentLoaded', () => {
if (window.answerQuills !== undefined){
	for (var i in window.answerQuills) {
		window.answerQuills[i].buttons = [
			{ 
				id: 'subscript', 
				latex: '_', 
				tooltip: 'subscript (_)', 
				icon: '\\\\text{ }_\\\\text{ }' 
			},
			{ 
				id: 'superscript', 
				latex: '^', 
				tooltip: 'superscript (^)', 
				icon: '\\\\text{ }^\\\\text{ }' 
			},
			{ 
				id: 'AXE', 
				latex: '_^', 
				tooltip: 'AXE format for nuclides', 
				icon: '_\\\\text{ }^\\\\text{ }\\\\text{ }' 
			},
			{ 
				id: 'species', 
				latex: '_^', 
				tooltip: 'species', 
				icon: '\\\\text{ }_\\\\text{ }^\\\\text{ }' 
			},
			{ 	id: 'positiveion',
			    	latex: '\\\\positiveion',
				tooltip: 'postitive ion',
				icon: '\\\\text{ }^{\\\\text{ }+}' 
			},
			{ 	id: 'negativeion',
			    	latex: '\\\\negativeion',
				tooltip: 'negative ion',
				icon: '\\\\text{ }^{\\\\text{ }-}' 
			},
			{ 	id: 'rightarrow',
			    	latex: '\\\\rightarrow',
				tooltip: 'right arrow',
				icon: '\\\\rightarrow' 
			},
			{
				id: 'equilibrium',
			    	latex: '\\\\equilibrium',
				tooltip: 'equilibrium',
				icon: '\\\\rightleftharpoons' 
			},
		];
	}
}

function disableMathQuill2(){
	var inputs = document.querySelectorAll('input[id^=MaThQuIlL_]');
	const reg = /(?:MaThQuIlL_)(.*)/g;
	for (var i=0; i<inputs.length; i++){		
		inputs[i].id = inputs[i].id.replace(reg, "$1");
	}
}

document.addEventListener('readystatechange', (e)=>{
	if (document.readyState == 'interactive'){
		const reg = /(?:MaThQuIlL_)(.*)/g;
		const inputs = document.querySelectorAll('input[id^=MaThQuIlL_]');
		for (var i=0; i<inputs.length; i++){
			inputs[i].parentElement.removeChild(inputs[i]);
		}
	}
});

function disableMathQuill() {
	// Observer that removes MathQuill inputs after they are created.
	const observer = new MutationObserver((mutationsList) => {
		mutationsList.forEach((mutation) => {
			mutation.addedNodes.forEach((node) => {
				if (node instanceof Element) {
					if (node.id && node.id.startsWith('mq-answer-')) {
						revertChanges(node);
					} else {
						node.querySelectorAll("span[id^='mq-answer-']").forEach((span) => revertChanges(span));
					}
				}
			});
		});
	});
	observer.observe(document.body, { childList: true, subtree: true });

	// Stop the mutation observer when the window is closed.
	window.addEventListener('unload', () => observer.disconnect());
	
}

function revertChanges(quillBlank){
	//var quillBlanks = document.querySelectorAll("span[id^='mq-answer-']");
	//for (var i = 0; i < quillBlanks.length; i++){
		quillBlank.parentElement.removeChild(quillBlank);
		var idname = quillBlank.id;
		const reg = /(?:mq-answer-)(.*)/g;
		var id = idname.replace(reg, "$1");
		console.log(id);
		var input = document.querySelector('#' + id);
		input.classList.remove('mq-edit'); 
	//}
}

window.disableMathQuill = this.disableMathQuill;
});
</script>
END_SCRIPT