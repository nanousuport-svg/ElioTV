# Faux serveur Xtream pour les tests (données de démo).
# Lancer : python3 tool/mock_xtream.py  →  http://127.0.0.1:8765, identifiants demo / demo+1
# Gros fournisseur simulé : python3 tool/mock_xtream.py --big  (20 000 chaînes, 80 000 films envoyés à ~1 Mo/s)
import json, base64, time, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HLS = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
HLS2 = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8"
MP4 = "https://test-videos.co.uk/vids/bigbuckbunny/mkv/360/Big_Buck_Bunny_360_10s_1MB.mkv"
b64 = lambda s: base64.b64encode(s.encode()).decode()
now = int(time.time())

BIG = "--big" in sys.argv
BIG_LIVE = [{"num": i, "name": f"FR: Chaîne {i}", "stream_id": 10000 + i, "stream_icon": "", "category_id": "1"} for i in range(1, 20001)]
BIG_VOD = [{"name": f"Film numéro {i} ({1980 + i % 45})", "stream_id": 200000 + i, "category_id": "10", "container_extension": "mkv",
            "rating": "7.1", "added": str(now - i), "genre": "Action, Aventure", "stream_icon": f"http://img.example/{i}.jpg"} for i in range(1, 80001)]

class H(BaseHTTPRequestHandler):
    def send_json(self, obj, rate=0):
        b = json.dumps(obj).encode(); self.send_response(200)
        self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b))); self.end_headers()
        if not rate: return self.wfile.write(b)
        for i in range(0, len(b), 64 * 1024):  # envoi lent : ~rate octets par seconde
            self.wfile.write(b[i:i + 64 * 1024]); time.sleep(64 * 1024 / rate)
    def redirect(self, url):
        self.send_response(302); self.send_header("Location", url); self.end_headers()
    def do_GET(self):
        u = urlparse(self.path); q = {k: v[0] for k, v in parse_qs(u.query).items()}
        sys.stderr.write(f"{self.path} UA={self.headers.get('User-Agent')}\n")
        if u.path == "/player_api.php":
            if q.get("username") != "demo" or q.get("password") != "demo+1":
                return self.send_json({"user_info": {"auth": 0}})
            a = q.get("action")
            if a is None: return self.send_json({"user_info": {"auth": 1, "status": "Active", "exp_date": str(now + 90*86400), "max_connections": "1"}})
            if a == "get_live_categories": return self.send_json([{"category_id": "1", "category_name": "Généraliste"}, {"category_id": 2, "category_name": "Sport"}])
            if BIG and a == "get_live_streams": return self.send_json(BIG_LIVE, rate=1_000_000)
            if BIG and a == "get_vod_streams": return self.send_json(BIG_VOD, rate=1_000_000)
            if a == "get_live_streams": return self.send_json([
                {"num": 1, "name": "Démo HD", "stream_id": 1, "stream_icon": "", "category_id": "1"},
                {"num": 2, "name": "Apple Bipbop", "stream_id": "2", "stream_icon": None, "category_id": "1"},
                {"num": 3, "name": "Chaîne en panne", "stream_id": 3, "category_id": "2"}])
            if a == "get_vod_categories": return self.send_json([{"category_id": "10", "category_name": "Animation"}])
            if a == "get_vod_streams": return self.send_json([{"name": "Big Buck Bunny", "stream_id": 100, "category_id": "10", "container_extension": "mp4"}])
            if a == "get_series_categories": return self.send_json([{"category_id": "20", "category_name": "Séries démo"}])
            if a == "get_series": return self.send_json([{"name": "Série Test", "series_id": 500, "category_id": "20"}])
            if a == "get_series_info": return self.send_json({"info": {"plot": "Une série de démonstration."}, "episodes": {"1": [
                {"id": "900", "episode_num": 1, "title": "Pilote", "container_extension": "mp4", "season": 1, "info": {"plot": "Le début", "duration": "00:10:00"}},
                {"id": "901", "episode_num": 2, "title": "Suite", "container_extension": "mp4", "season": 1}], "2": [
                {"id": "902", "episode_num": 1, "title": "Saison 2", "container_extension": "mp4", "season": 2}]}})
            if a == "get_short_epg": return self.send_json({"epg_listings": [
                {"title": b64("Journal de 20h"), "description": b64("Infos"), "start_timestamp": str(now - 600), "stop_timestamp": str(now + 1200)},
                {"title": b64("Film du soir"), "start_timestamp": str(now + 1200), "stop_timestamp": str(now + 7200)}]})
            return self.send_json([])
        p = u.path
        if p.startswith("/live/demo/demo+1/1.m3u8") or p.startswith("/live/demo/demo%2B1/1.m3u8"): return self.redirect(HLS)
        if "/live/" in p and p.endswith("/2.m3u8"): return self.redirect(HLS2)
        if "/movie/" in p: return self.redirect(MP4)
        if "/series/" in p: return self.redirect(MP4)
        self.send_response(404); self.end_headers()

ThreadingHTTPServer(("127.0.0.1", 8765), H).serve_forever()
