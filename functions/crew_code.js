// 크루 초대 코드 규칙. 서버 함수 crewCode가 이 판단을 트랜잭션 안에서 적용합니다.
// 판단 부분은 서버에 닿지 않아 node --test로 시험합니다.
//
// 코드: 영어 대문자·숫자 6자리. 헷갈리는 0·O·1·I·L은 쓰지 않습니다.
// - crews/{크루}.code: 지금 코드(멤버가 서랍에서 봅니다).
// - crewCodes/{코드}: { crewId, createdAt }. 코드로 크루를 찾는 문서이고 앱은 읽지 못합니다(서버만).
// - crews/{크루}/banned/{uid}: 크루장이 내보낸 사람. 코드로는 다시 못 들어오고, 크루장이 다시 초대해 수락하면 지워집니다.

/** 코드에 쓰는 글자(0·O·1·I·L 뺌). */
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/** 코드 글자 수. */
const CODE_LENGTH = 6;

/** 크루 최대 인원(앱의 Crew.maxMembers와 같습니다). */
const MAX_MEMBERS = 200;

/** 사용자에게 그대로 보여 줄 이유를 담은 오류. */
class CodeError extends Error {}

/** 새 코드. [random]은 0 이상 1 미만을 돌려주는 함수입니다(시험에서 바꿉니다). */
function makeCode(random = Math.random) {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[Math.floor(random() * CODE_ALPHABET.length)];
  }
  return code;
}

/** 입력한 코드를 대문자로 바꾸고 띄어쓰기를 지웁니다. 코드 모양이 아니면 null. */
function normalizeCode(text) {
  const code = String(text || '').replace(/\s/g, '').toUpperCase();
  if (code.length !== CODE_LENGTH) return null;
  for (const c of code) {
    if (!CODE_ALPHABET.includes(c)) return null;
  }
  return code;
}

/**
 * 코드로 들어갈 수 있는지 판단합니다. 들어가야 하면 'join', 이미 멤버면 'member'를 돌려주고,
 * 안 되면 [CodeError]를 던집니다.
 * - crew: 크루 문서(없으면 null), code: 입력한 코드, uid: 들어오려는 사람
 * - banned: 내보내진 사람인지, blocked: 크루장과 한쪽이라도 차단했는지
 */
function decideJoin({ crew, code, uid, banned, blocked }) {
  // 지워진 크루이거나 코드가 바뀌었으면 없는 코드로 봅니다.
  if (!crew || crew.code !== code) throw new CodeError('코드를 다시 확인해 주세요');
  const members = crew.members || [];
  if (members.includes(uid)) return 'member';
  if (banned) throw new CodeError('이 크루에는 코드로 들어갈 수 없어요');
  if (blocked) throw new CodeError('이 크루에는 들어갈 수 없어요');
  if (members.length >= MAX_MEMBERS) throw new CodeError('크루는 200명까지예요');
  return 'join';
}

/** 코드를 새로 만들 수 있는지 판단합니다(크루장만). */
function decideIssue({ crew, uid }) {
  if (!crew) throw new CodeError('크루를 찾을 수 없어요');
  if (crew.owner !== uid) throw new CodeError('크루장만 코드를 바꿀 수 있어요');
}

module.exports = {
  CODE_ALPHABET,
  CODE_LENGTH,
  MAX_MEMBERS,
  CodeError,
  makeCode,
  normalizeCode,
  decideJoin,
  decideIssue,
};
