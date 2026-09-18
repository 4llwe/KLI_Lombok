import {signIn} from './api.js';
const form=document.querySelector('#login-form'),status=document.querySelector('#login-status');
form?.addEventListener('submit',async event=>{event.preventDefault();status.textContent='Memeriksa akun…';const button=form.querySelector('button[type=submit]');button.disabled=true;try{const data=Object.fromEntries(new FormData(form));await signIn(data.email,data.password);location.href='/portal.html'}catch(error){status.textContent=error.message}finally{button.disabled=false}});
