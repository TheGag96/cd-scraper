import arsd.http2;
import arsd.dom;
import std.stdio, std.algorithm, std.string, std.conv, std.parallelism;
import core.thread, core.memory;
import libnotify4d;

//__gshared bool[ulong] ignoreTable;
bool[ulong] ignoreTable;
bool newCds = false;

string[] cds = [
  "山下達郎 go ahead cd",
  "たそがれ 山根麻衣 cd",
  "ドリームクルーズ cd",
  "relief 72 hours cd",
  "native son shining cd",
  "tea for tears cd",
  "細野晴臣 パシフィック cd",
  "cindy love life cd",
  "スーパーマリオワールド cd -3d -トロピカルコンピューター",
  //"山下達郎 for you cd -christmas -ballad",
  //"山下達郎 ride on time cd",
  //"山下達郎 spacy cd",
];

void main() {
  writefln("  %8s円 | %10s | %s", "Price", "Time left", "URL");

  while (true) {
    cds.each!findCd;
    //foreach (cd; cds.parallel(1)) {
    //  findCd(cd);
    //}

    if (newCds) {
      newCds = false;

      Notification notif = new Notification("New CD listings found!", "Check the terminal.");
      notif.show;
    }

    writeln("------------");

    GC.collect();
    Thread.sleep(1.hours);
  }
}

void findCd(string name) {
  //exclude bookoff2016
  enum URL_FORMAT = `https://auctions.yahoo.co.jp/search/search?auccat=&tab_ex=commerce&ei=utf-8&aq=0&oq=&fr=auc_top&exsid=bookoff2016&p=%s&sc_i=auc_sug`;

  auto url = format(URL_FORMAT, name.replace(" ", "+"));

  auto doc = Document.fromUrl(url);

  auto candidates = doc
    .getElementsByClassName("Product")
    .map!unpack
    .filter!wantToCheck;

  //synchronized {
    writeln(name, ":");

    //sometimes search results come back empty, but there will still be products on the page anyway. skip processing in that case
    auto notices = doc.getElementsByClassName("Notice__wandText");
    if (notices.length && notices[0].directText.canFind("致する商品はありません")) {
      return;
    }

    candidates.each!processCd;
  //}
}

struct Candidate {
  string title;
  string url;
  int price;
  string timeLeft;
}

Candidate unpack(Element elem) {
  auto titleLink = elem.getElementsByClassName("Product__titleLink")[0];
  auto price     = elem.getElementsByClassName("Product__priceValue")[0];
  auto time      = elem.getElementsByClassName("Product__time")[0];

  return Candidate(
    titleLink.attrs["title"],
    titleLink.attrs["href"],
    price.directText.parsePrice,
    time.directText.parseTimeLeft
  );
}

int parsePrice(string price) {
  return price[0..price.countUntil("円")].splitter(",").joiner.to!int;
}

string parseTimeLeft(string timeLeft) {
  if (timeLeft.endsWith("時間")) {
    return timeLeft.replace("時間", " hours");
  }
  else if (timeLeft.endsWith("日")) {
    return timeLeft.replace("日", " days");
  }
  return timeLeft;
}

ulong getNumFromUrl(string url) {
  //combine letter part and numeric part
  auto lastSlashLoc = url.lastIndexOf("/");
  return url[lastSlashLoc+2..$].to!ulong + url[lastSlashLoc+1] << 32;
}

bool wantToCheck(Candidate candidate) {
  auto lower = candidate.title.toLower;

  if (ignoreTable.get(candidate.url.getNumFromUrl, false)) {
    return false;
  }

  if (lower.canFind("lp") || lower.canFind("dvd") || lower.canFind("ld") || lower.canFind("カセット")) {
    return false;
  }

  if (lower.canFind("anniversary") || lower.canFind("ａｎｎｉｖｅｒｓａｒｙ") || lower.canFind("blu")) {
    return false;
  }

  return true;
}

void processCd(Candidate candidate) {
  ignoreTable[candidate.url.getNumFromUrl] = true;
  newCds = true;

  //auto itemPage = Document.fromUrl(candidate.url);

  writefln("  %8s円 | %10s | %s", candidate.price, candidate.timeLeft, candidate.url);
}