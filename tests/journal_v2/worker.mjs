import {createJournalV2} from '/lib/finance/journal_v2/browser_journal_v2.mjs';
const journal = createJournalV2({ownerUid:'synthetic', teamId:'team', sessionIsCurrent:()=>true});
onmessage = async ({data}) => {
  try { postMessage({ok: true, result: await journal[data.action](data.raw)}); }
  catch (error) { postMessage({ok: false, code: error.message}); }
};
