HEADER_TEXT( MODES(TeX=>'', HTML=><<END_SCRIPT ));
<script>

window.addEventListener('DOMContentLoaded', () => {
if (window.answerQuills !== undefined){
	for (var i in window.answerQuills) {
        // this will prevent MathQuill from ex: auto formating "sec" inside of "picoseconds" to "pico sec onds" 
        window.answerQuills[i].mathField.config({autoCommands:'needAsuperLONGstringJUSTnotBLANK', autoOperatorNames:'needAsuperLONGstringJUSTnotBLANK'});
        // we also need to repopulate the fields because they've probably already been formatted badly
        var rawText = window.answerQuills[i].innerText;
        window.answerQuills[i].mathField.empty();
        window.answerQuills[i].mathField.typedText(rawText);

        // this redoes the buttons that show up
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
			{ 	id: 'scinotation',
			    	latex: '\\\\sci',
				tooltip: 'Scientific Notation',
				icon: 'Sci' 
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
    console.log(e);
	if (document.readyState == 'interactive'){
		const reg = /(?:MaThQuIlL_)(.*)/g;
		const inputs = document.querySelectorAll('input[id^=MaThQuIlL_]');
		for (var i=0; i<inputs.length; i++){
            console.log("OVERRIDE");
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