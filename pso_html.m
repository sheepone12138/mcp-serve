% 读取PSO优化结果
load('pso_result.mat', 'x_real', 'gbest', 'f', 'gbest_val', 'gbest_hist');

header = {'电机峰值功率（kW）','电池容量（kWh）','发动机排量（L）','变速器档位数'};

% 反归一化参数
params_real = x_real;
params_norm = gbest;

% 目标函数结果
acc_time = f(1); % 0-50加速时间
fuel = f(2);     % 百公里油耗
w_acc = 0.7;
w_fuel = 0.3;

% 打开HTML文件
fid = fopen('pso_result.html','w','n','UTF-8');
fprintf(fid, '<!DOCTYPE html>\n<html lang="zh-CN">\n<head>\n<meta charset="UTF-8">\n<title>PSO最优解结果</title>\n');
fprintf(fid, '<style>table{border-collapse:collapse;}th,td{border:1px solid #888;padding:4px;}</style>\n');
fprintf(fid, '</head>\n<body>\n');
fprintf(fid, '<h2>PSO优化最优解及收敛曲线</h2>\n');
fprintf(fid, '<img src="pso_converge.png" alt="PSO收敛曲线" style="max-width:600px;"><br><br>\n');

fprintf(fid, '<h3>最优解参数（归一化）</h3>\n');
fprintf(fid, '<table><tr>');
for i=1:4
    fprintf(fid, '<th>%s</th>', header{i});
end
fprintf(fid, '</tr><tr>');
for j=1:4
    fprintf(fid, '<td>%.4f</td>', params_norm(j));
end
fprintf(fid, '</tr></table>\n');

fprintf(fid, '<h3>最优解参数（反归一化物理量）</h3>\n');
fprintf(fid, '<table><tr>');
for i=1:4
    fprintf(fid, '<th>%s</th>', header{i});
end
fprintf(fid, '</tr><tr>');
for j=1:4
    fprintf(fid, '<td>%.2f</td>', params_real(j));
end
fprintf(fid, '</tr></table>\n');

fprintf(fid, '<h3>目标函数结果</h3>\n');
fprintf(fid, '<table><tr><th>目标</th><th>数值</th><th>权重</th></tr>');
fprintf(fid, '<tr><td>0-50加速时间 (s)</td><td>%.2f</td><td>%.2f</td></tr>', acc_time, w_acc);
fprintf(fid, '<tr><td>百公里油耗 (g/100km)</td><td>%.2f</td><td>%.2f</td></tr>', fuel, w_fuel);
fprintf(fid, '</table>\n');

fprintf(fid, '<p>说明：本次PSO优化采用单目标加权法，两个目标的权重分别为：动力性（0-50加速时间）%.2f，经济性（百公里油耗）%.2f。</p>\n', w_acc, w_fuel);

fprintf(fid, '</body>\n</html>');
fclose(fid); 