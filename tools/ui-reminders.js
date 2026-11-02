async (page) => {
  const checks=[], errors=[];
  const check=(value,label)=>{if(!value)throw Error(label);checks.push(label);};
  page.on('pageerror',error=>errors.push(error.message));
  await page.addInitScript(()=>{
    const defaults={enabled:false,frequency:'daily',hour:20,minute:0,weekday:1,monthDay:1,locale:'es',canNotify:true,nextAt:0};
    const read=()=>JSON.parse(localStorage.getItem('test-reminders')||JSON.stringify(defaults));
    window.BrujulaNative={
      read:()=>localStorage.getItem('brujula-state-v1')||'',
      write:text=>{localStorage.setItem('brujula-state-v1',text);return true;},
      readReminders:()=>JSON.stringify(read()),
      configureReminder:text=>{
        const proposed=JSON.parse(text),blocked=window.__denyNotifications&&proposed.enabled;
        if(!blocked)localStorage.setItem('test-reminders',JSON.stringify({...proposed,canNotify:true,nextAt:proposed.enabled?Date.now()+3600000:0}));
        window.reminderResult({ok:!blocked,key:blocked?'reminderBlocked':proposed.enabled?'reminderSaved':'reminderDisabled',settings:read()});
      },
      updateReminderLocale:locale=>{localStorage.setItem('test-reminders',JSON.stringify({...read(),locale}));},
      exportBackup:text=>localStorage.setItem('test-export',text),
      importBackup:()=>{},notificationSettings:()=>{window.__openedSettings=true;}
    };
  });
  await page.reload();
  const state=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('brujula-state-v1')));
  const reminder=()=>page.evaluate(()=>JSON.parse(window.BrujulaNative.readReminders()));
  check((await state()).history.length===0,'Fresh installation has no historical check-ins');
  check(Object.values((await state()).draft.scores).every(v=>v===null),'Fresh installation has no preset scores');
  check(await page.getByRole('button',{name:'Salud, Sin valorar',exact:true}).isVisible(),'Unanswered scores are labeled clearly');
  await page.screenshot({path:'output/playwright/clean-wheel.png',fullPage:true});
  await page.getByRole('button',{name:'Historial',exact:true}).click();
  check(await page.getByText('Aquí aparecerán tus evaluaciones. Guarda un momento desde Mi rueda.').isVisible(),'History starts with an empty state');
  await page.getByRole('button',{name:'Mi rueda',exact:true}).click();
  await page.getByRole('button',{name:'Guardar evaluación',exact:true}).click();
  check((await state()).history.length===0,'An incomplete wheel cannot be recorded as an evaluation');
  const categories=['Salud','Trabajo','Finanzas','Familia','Amistades','Pareja','Ocio','Crecimiento'];
  for(const [index,name] of categories.entries()){
    await page.getByRole('button',{name:name+', Sin valorar',exact:true}).click();
    if(index===0){
      await page.getByRole('textbox',{name:'Tu reflexión',exact:true}).fill('My own reflection <img src=x onerror=alert(1)>');
      await page.getByRole('slider',{name,exact:true}).focus();
      await page.keyboard.press('Home');
      check((await state()).draft.scores.health===0,'An explicit zero is saved rather than treated as unanswered');
      await page.keyboard.press('End');
      check((await state()).draft.scores.health===10,'The upper score bound still works');
    }else await page.getByRole('button',{name:name+' +1',exact:true}).click();
    await page.getByRole('button',{name:'Listo',exact:true}).click();
  }
  await page.getByRole('button',{name:'Guardar evaluación',exact:true}).click();
  await page.getByRole('textbox',{name:'Dale un nombre (opcional)',exact:true}).fill('My first reflection');
  await page.getByRole('button',{name:'Guardar este momento',exact:true}).click();
  check((await state()).history.length===1,'Only an intentional evaluation becomes the first history item');
  await page.reload();
  check((await state()).history[0].notes.health.includes('<img'),'User scores, history and literal notes survive reload');
  await page.getByRole('button',{name:'Ajustes',exact:true}).click();
  await page.getByRole('button',{name:'Recordatorio de reflexión',exact:true}).click();
  check(!await page.getByRole('switch',{name:'Activar recordatorio',exact:true}).isChecked(),'Reminders are disabled by default');
  await page.getByRole('switch',{name:'Activar recordatorio',exact:true}).check();
  await page.getByRole('combobox',{name:'Frecuencia',exact:true}).selectOption('weekly');
  await page.getByRole('combobox',{name:'Día de la semana',exact:true}).selectOption('5');
  await page.getByLabel('Hora',{exact:true}).fill('19:45');
  await page.screenshot({path:'output/playwright/weekly-reminder.png'});
  await page.getByRole('button',{name:'Guardar recordatorio',exact:true}).click();
  let r=await reminder();
  check(r.enabled&&r.frequency==='weekly'&&r.weekday===5&&r.hour===19&&r.minute===45,'A weekly reminder saves weekday and time through the native bridge');
  await page.getByRole('combobox',{name:'Frecuencia',exact:true}).selectOption('monthly');
  await page.getByRole('combobox',{name:'Día del mes',exact:true}).selectOption('31');
  check(await page.getByText('Si ese día no existe en un mes, se usará su último día.').isVisible(),'Short-month handling is explained');
  await page.screenshot({path:'output/playwright/monthly-reminder.png'});
  await page.getByRole('button',{name:'Guardar recordatorio',exact:true}).click();
  r=await reminder();check(r.frequency==='monthly'&&r.monthDay===31,'A monthly reminder saves its calendar day');
  await page.getByRole('combobox',{name:'Frecuencia',exact:true}).selectOption('daily');
  await page.getByLabel('Hora',{exact:true}).fill('08:15');
  await page.getByRole('button',{name:'Guardar recordatorio',exact:true}).click();
  r=await reminder();check(r.frequency==='daily'&&r.hour===8&&r.minute===15,'A daily reminder saves its time');
  await page.getByRole('switch',{name:'Activar recordatorio',exact:true}).uncheck();
  await page.getByRole('button',{name:'Guardar recordatorio',exact:true}).click();
  check(!(await reminder()).enabled,'The user can disable a saved reminder');
  await page.evaluate(()=>window.__denyNotifications=true);
  await page.getByRole('switch',{name:'Activar recordatorio',exact:true}).check();
  await page.getByRole('button',{name:'Guardar recordatorio',exact:true}).click();
  check(!(await reminder()).enabled,'A denied permission does not falsely show a successful enable');
  await page.evaluate(()=>window.__denyNotifications=false);
  await page.getByRole('button',{name:'Cerrar',exact:true}).click();
  await page.getByRole('button',{name:'Ajustes',exact:true}).click();
  await page.getByRole('button',{name:'English',exact:true}).click();
  await page.getByRole('button',{name:'Reflection reminder',exact:true}).click();
  check(await page.getByRole('switch',{name:'Enable reminder',exact:true}).isVisible(),'Reminder settings are translated into English');
  await page.getByRole('button',{name:'Close',exact:true}).click();
  await page.getByRole('button',{name:'Settings',exact:true}).click();
  await page.getByRole('button',{name:'Clear data and start fresh',exact:true}).click();
  await page.getByRole('button',{name:'Cancel',exact:true}).click();
  check((await state()).history.length===1,'Cancelling a reset keeps existing data');
  await page.getByRole('button',{name:'Settings',exact:true}).click();
  await page.getByRole('button',{name:'Clear data and start fresh',exact:true}).click();
  await page.getByRole('button',{name:'Delete my data',exact:true}).click();
  let fresh=await state();
  check(fresh.history.length===0&&Object.values(fresh.draft.scores).every(v=>v===null)&&Object.values(fresh.draft.notes).every(v=>v===''),'Confirmed reset removes scores, notes and history');
  check(!(await reminder()).enabled,'Reset also disables the reminder');
  const old=await page.evaluate(()=>{
    const entry=window.BrujulaCore.initial();entry.version=1;entry.locale='es';
    Object.keys(entry.draft.scores).forEach(id=>entry.draft.scores[id]=6);
    entry.draft.notes.family='Preserve my existing note';
    entry.history=[{id:'legacy-check-in',at:'2026-10-01T10:00:00Z',title:'Existing check-in',scores:{...entry.draft.scores},notes:{...entry.draft.notes}}];
    return entry;
  });
  await page.evaluate(value=>{localStorage.setItem('brujula-state-v1',JSON.stringify(value));},old);
  await page.reload();
  const migrated=await state();
  check(migrated.version===2&&migrated.history.length===1&&migrated.draft.notes.family==='Preserve my existing note','An existing installation is migrated without silent deletion');
  await page.evaluate(()=>window.restoreBackup('{broken json'));
  check((await state()).history.length===1,'Invalid backups cannot overwrite current data');
  for(const width of [320,393,768]){
    await page.setViewportSize({width,height:852});
    check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'No horizontal overflow at width '+width);
  }
  check(errors.length===0,'No JavaScript runtime errors');
  await page.evaluate(()=>localStorage.clear());await page.setViewportSize({width:393,height:852});await page.reload();
  await page.screenshot({path:'output/playwright/clean-wheel-viewport.png'});
  return {passed:checks.length,checks};
}
