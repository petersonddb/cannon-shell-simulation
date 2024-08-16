#include <fstream>
#include <math.h>
#include <nlohmann/detail/macro_scope.hpp>
#include <nlohmann/json.hpp>
#include <nlohmann/json_fwd.hpp>
#include <string>
#include <vector>

const double deg2rad = M_PI / 180;

using json = nlohmann::json;

struct point {
  double x, y;
};

struct v {
  double x, y;

  double operator()();
  double theta();
};

struct params {
  double g = 9.8;
  double p, y0, b2_per_mass, time_step;

  v v0;
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(v, x, y)
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(params, v0, b2_per_mass, p, y0, time_step)

struct data {
  std::vector<double> t;
  std::vector<point> point;
  std::vector<double> p;
};

void load_params(params &p, std::string file_name);
void until_best_results(params &p, std::string file_name,
                        void (*calculate)(data &d, const params &p),
                        void (*store_data)(const data &d,
                                           std::string file_name));
void calculate(data &d, const params &p);
void store_data(const data &d, std::string file_name);

int main(int argc, char **argv) {
  params p;
  std::string params_file_name(argv[1]);
  std::string data_file_name(argv[1]);
  data_file_name.replace(data_file_name.find(".json"), 5, ".dat");

  load_params(p, params_file_name);
  until_best_results(p, data_file_name, calculate, store_data);
}

double v::operator()() { return sqrt(x * x + y * y); }

double v::theta() { return atan(y / x) * (1 / deg2rad); }

void load_params(params &p, std::string file_name) {
  std::ifstream file(file_name);
  json read_json{json::parse(file)};
  read_json.get_to(p);
}

void until_best_results(params &p, std::string file_name,
                        void (*calculate)(data &d, const params &p),
                        void (*store_data)(const data &d,
                                           std::string file_name)) {
  data d;

  std::string adjusted_file_name =
      std::to_string(int(round(p.v0.theta()))) + file_name;

  calculate(d, p);
  store_data(d, adjusted_file_name);

  double tmp_x;
  do {
    tmp_x = d.point.back().x;
    d.point.clear();
    d.t.clear();
    d.p.clear();

    // TODO: matrix rotation is the preferred way of math (this is unstable
    // though)
    // p.v0 = {p.v0.x * cos(1 * deg2rad) - p.v0.y * sin(1 * deg2rad),
    //         p.v0.y * sin(1 * deg2rad) + p.v0.x * cos(1 * deg2rad)};

    p.v0 = {p.v0() * cos((p.v0.theta() + 1) * deg2rad),
            p.v0() * sin((p.v0.theta() + 1) * deg2rad)};

    adjusted_file_name = std::to_string(int(round(p.v0.theta()))) + file_name;

    calculate(d, p);
    store_data(d, adjusted_file_name);
  } while (tmp_x <= d.point.back().x);
}

void calculate(data &d, const params &p) {
  int i = 0;
  v v(p.v0);

  d.t.push_back(0);
  d.point.push_back({0, 0});
  d.p.push_back(p.p);
  for (; d.point[i].y >= 0; i++) {
    d.t.push_back(d.t[i] + p.time_step);

    d.point.push_back(
        {d.point[i].x + v.x * p.time_step, d.point[i].y + v.y * p.time_step});

    double drag_acceleration = d.p[i] / p.p * p.b2_per_mass * v();
    v = {v.x - drag_acceleration * v.x * p.time_step,
         v.y - (drag_acceleration * v.y + p.g) * p.time_step};

    d.p.push_back(p.p *
                  exp(-d.point[i + 1].y /
                      p.y0)); // NOTE: this is an analytical solution, not numerical
  }

  // NOTE: t was left incorrect (DON'T DO THIS!)
  double r = -d.point[i - 1].y / d.point[i].y;
  d.point[i] = {(d.point[i - 1].x + r * d.point[i].x) / (r + 1), 0};
  d.p[i] = p.p;
}

void store_data(const data &d, std::string file_name) {
  std::ofstream file(file_name);
  int n = d.t.size();

  for (int i = 0; i < n; i++) {
    file << d.t[i] << " " << d.point[i].x << " " << d.point[i].y << " "
         << d.p[i] << std::endl;
  }
}
