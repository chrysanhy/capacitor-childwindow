import { ChildWindow } from 'capacitor-childwindow';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    ChildWindow.echo({ value: inputValue })
}
