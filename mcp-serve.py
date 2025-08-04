#!/usr/bin/env python3
"""
MCP服务器 - 适用于MCP 1.6.0版本
使用FastMCP API
"""

import asyncio
import json
import sys
import subprocess
from typing import List
from pathlib import Path
from mcp.server.fastmcp import FastMCP

# 配置：指定要调用的Python脚本路径
SCRIPT_CONFIG = {
    "script_path": "./PSO.py",
    "script_name": "PSO优化器",
    "description": "使用粒子群算法(PSO)优化混合动力汽车参数",
    "working_directory": ".",
}

# 创建FastMCP应用实例
mcp = FastMCP("PSO优化器")

@mcp.tool()
async def run_pso_optimization(
    optimization_mode: str = "default",
    motor_power_range: List[float] = [40, 80],
    battery_capacity_range: List[float] = [15, 35], 
    engine_displacement_range: List[float] = [1.5, 2.2],
    gear_count_range: List[float] = [4, 6]
) -> str:
    """
    调用PSO优化器进行混合动力汽车参数优化
    
    Args:
        optimization_mode: 优化模式，'default'使用默认参数，'custom'使用自定义参数
        motor_power_range: 电机功率范围 [最小值, 最大值] (kW)
        battery_capacity_range: 电池容量范围 [最小值, 最大值] (kWh)
        engine_displacement_range: 发动机排量范围 [最小值, 最大值] (L)
        gear_count_range: 档位数范围 [最小值, 最大值]
    
    Returns:
        优化结果的字符串表示
    """
    
    try:
        script_path = Path(SCRIPT_CONFIG["script_path"])
        if not script_path.exists():
            return f"❌ 错误：PSO脚本文件不存在: {script_path.absolute()}"
        
        # 准备Python代码
        if optimization_mode == "default":
            python_code = f"""
import sys
import os
sys.path.append('{script_path.parent.absolute()}')
os.chdir('{Path(SCRIPT_CONFIG["working_directory"]).absolute()}')

try:
    from {script_path.stem} import call_pso_optimization
    import json
    
    print("🚀 开始PSO优化（默认参数）...")
    results = call_pso_optimization()
    print("\\n📊 优化完成！")
    print("RESULT_JSON:", json.dumps(results, ensure_ascii=False))
except Exception as e:
    print(f"ERROR: {{str(e)}}")
    import traceback
    traceback.print_exc()
"""
        else:  # custom mode
            python_code = f"""
import sys
import os
sys.path.append('{script_path.parent.absolute()}')
os.chdir('{Path(SCRIPT_CONFIG["working_directory"]).absolute()}')

try:
    from {script_path.stem} import call_pso_optimization
    import json
    
    print("🚀 开始PSO优化（自定义参数）...")
    custom_params = [
        {motor_power_range},
        {battery_capacity_range},
        {engine_displacement_range},
        {gear_count_range}
    ]
    
    print(f"📋 参数范围:")
    print(f"  电机功率: {motor_power_range[0]}-{motor_power_range[1]} kW")
    print(f"  电池容量: {battery_capacity_range[0]}-{battery_capacity_range[1]} kWh")
    print(f"  发动机排量: {engine_displacement_range[0]}-{engine_displacement_range[1]} L")
    print(f"  档位数: {gear_count_range[0]}-{gear_count_range[1]}")
    
    results = call_pso_optimization(custom_params)
    print("\\n📊 优化完成！")
    print("RESULT_JSON:", json.dumps(results, ensure_ascii=False))
except Exception as e:
    print(f"ERROR: {{str(e)}}")
    import traceback
    traceback.print_exc()
"""
        
        # 执行Python代码
        process = await asyncio.create_subprocess_exec(
            sys.executable, "-c", python_code,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=SCRIPT_CONFIG["working_directory"]
        )
        
        stdout, stderr = await process.communicate()
        stdout_text = stdout.decode('utf-8', errors='replace')
        stderr_text = stderr.decode('utf-8', errors='replace')
        
        # 构建结果
        result_parts = []
        
        if process.returncode == 0:
            result_parts.append("✅ PSO优化执行成功！")
            
            # 解析结果
            if "RESULT_JSON:" in stdout_text:
                try:
                    json_start = stdout_text.find("RESULT_JSON:") + len("RESULT_JSON:")
                    json_text = stdout_text[json_start:].strip()
                    results_json = json.loads(json_text)
                    
                    result_parts.append("\\n🎯 **优化结果摘要**:")
                    if '最优物理参数' in results_json:
                        params = results_json['最优物理参数']
                        result_parts.append(f"  • 电机功率: {params[0]:.2f} kW")
                        result_parts.append(f"  • 电池容量: {params[1]:.2f} kWh")
                        result_parts.append(f"  • 发动机排量: {params[2]:.2f} L")
                        result_parts.append(f"  • 档位数: {params[3]:.0f}")
                    
                    if '加速时间(s)' in results_json:
                        result_parts.append(f"  • 加速时间: {results_json['加速时间(s)']:.2f} s")
                    if '油耗(g/100km)' in results_json:
                        result_parts.append(f"  • 油耗: {results_json['油耗(g/100km)']:.2f} g/100km")
                    if '最终目标值' in results_json:
                        result_parts.append(f"  • 目标值: {results_json['最终目标值']:.4f}")
                        
                except Exception as e:
                    result_parts.append(f"⚠️ 结果解析失败: {e}")
            
            # 添加详细输出
            result_parts.append("\\n📝 **详细输出**:")
            result_parts.append(f"```\\n{stdout_text}\\n```")
            
        else:
            result_parts.append(f"❌ PSO优化执行失败 (退出码: {process.returncode})")
            if stderr_text.strip():
                result_parts.append(f"\\n🚨 **错误信息**:")
                result_parts.append(f"```\\n{stderr_text}\\n```")
            if stdout_text.strip():
                result_parts.append(f"\\n📤 **标准输出**:")
                result_parts.append(f"```\\n{stdout_text}\\n```")
        
        # 添加执行信息
        mode_desc = "默认参数" if optimization_mode == "default" else "自定义参数"
        result_parts.append(f"\\n🔧 **执行模式**: {mode_desc}")
        
        return "\\n".join(result_parts)
        
    except Exception as e:
        return f"❌ 执行PSO优化时发生错误: {str(e)}\\n\\n请检查：\\n1. PSO.py文件是否存在\\n2. MATLAB引擎是否正确安装\\n3. 工作目录权限是否正确"

def main():
    """启动MCP服务器"""
    # 检查脚本文件
    script_path = Path(SCRIPT_CONFIG["script_path"])
    if not script_path.exists():
        print(f"警告: 脚本文件不存在: {script_path.absolute()}", file=sys.stderr)
        print(f"请确保PSO.py文件在当前目录下", file=sys.stderr)
    
    # 使用FastMCP的运行方式
    mcp.run()

if __name__ == "__main__":
    main()