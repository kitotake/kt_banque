(function(){
  const RESOURCE = 'REPLACE_WITH_RESOURCE_NAME' // à remplacer par le nom du dossier

  const app = document.getElementById('app')
  const loading = document.getElementById('loading')
  const balanceEl = document.getElementById('balance')
  const accountLabel = document.getElementById('accountLabel')
  const historyList = document.getElementById('historyList')
  const pinScreen = document.getElementById('pin-screen')
  const pinInput = document.getElementById('pinInput')
  const pinSubmit = document.getElementById('pinSubmit')
  const pinError = document.getElementById('pinError')

  const closeBtn = document.getElementById('closeBtn')
  const depositBtn = document.getElementById('depositBtn')
  const withdrawBtn = document.getElementById('withdrawBtn')
  const transferBtn = document.getElementById('transferBtn')

  let playerCard = null
  let enteredPIN = null

  function openPinScreen(card){
    playerCard = card
    loading.classList.add('hidden')
    pinScreen.classList.remove('hidden')
  }

  function verifyPIN(){
    const entered = pinInput.value.trim()
    if(entered.length !== 4 || isNaN(entered)) return alert('PIN invalide')
    if(entered === playerCard.pin){
      enteredPIN = entered
      pinScreen.classList.add('hidden')
      openUI(playerCard)
    } else {
      pinError.classList.remove('hidden')
      setTimeout(() => pinError.classList.add('hidden'), 2000)
    }
  }

  function openUI(data){
    app.classList.remove('hidden')
    updateBalance(data.balance || 0)
    accountLabel.textContent = data.label ? `Compte: ${data.label}` : 'Compte: personnel'
    renderHistory(data.history || [])
  }

  function closeUI(){
    app.classList.add('hidden')
    loading.classList.remove('hidden')
    fetch(`https://${RESOURCE}/close`, {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({})})
  }

  function updateBalance(amount){
    balanceEl.textContent = `$${Number(amount).toLocaleString('fr-FR')}`
  }

  function renderHistory(items){
    historyList.innerHTML = ''
    if(items.length === 0){
      historyList.innerHTML = '<li>Aucune transaction</li>'
      return
    }
    items.forEach(it => {
      const li = document.createElement('li')
      const time = it.time ? new Date(it.time).toLocaleString('fr-FR') : ''
      li.textContent = `${time} — ${it.label || it.type || 'tx'} — ${it.amount ? '$'+it.amount : ''}`
      historyList.appendChild(li)
    })
  }

  // NUI messages
  window.addEventListener('message', (event) => {
    const d = event.data
    if(!d) return
    switch(d.action){
      case 'openPin':
        openPinScreen(d.card)
        break
      case 'open':
        openUI(d.data || {})
        break
      case 'updateBalance':
        updateBalance(d.balance)
        break
      case 'close':
        closeUI()
        break
    }
  })

  // actions
  pinSubmit.addEventListener('click', verifyPIN)
  closeBtn.addEventListener('click', closeUI)

  depositBtn.addEventListener('click', () => {
    const amount = Number(document.getElementById('depositAmount').value)
    if(!amount || amount <= 0) return alert('Montant invalide')
    fetch(`https://${RESOURCE}/deposit`, {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({amount, pin: enteredPIN})
    })
  })

  withdrawBtn.addEventListener('click', () => {
    const amount = Number(document.getElementById('withdrawAmount').value)
    if(!amount || amount <= 0) return alert('Montant invalide')
    fetch(`https://${RESOURCE}/withdraw`, {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({amount, pin: enteredPIN})
    })
  })

  transferBtn.addEventListener('click', () => {
    const target = document.getElementById('transferTarget').value
    const amount = Number(document.getElementById('transferAmount').value)
    if(!target) return alert('Indiquez un destinataire')
    if(!amount || amount <= 0) return alert('Montant invalide')
    fetch(`https://${RESOURCE}/transfer`, {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({target, amount, pin: enteredPIN})
    })
  })

  // ESC
  document.addEventListener('keydown', (e) => {
    if(e.key === 'Escape') closeUI()
  })

  // test
  window.NUI_TEST_OPEN = function(){
    openPinScreen({pin:"1234", balance:4500, label:"perso", history:[{time:Date.now(),label:"Dépôt",amount:1000}]})
  }
})();
